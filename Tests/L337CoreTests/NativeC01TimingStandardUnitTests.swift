import Foundation
import Testing

@testable import L337Core

/// Component facts only; deliberately unauthenticated by a real commission/audit.
/// These records cannot qualify a recovery journey or create a live pending token.
private struct C01TimingStandardFacts {
  let source: NativeC01TimingStandardSource
  let marker: ScriptOwnedActor
  let player: ActorIdentity
  let carrier = UUID()

  init() throws {
    var native = FlightSimulationState()
    for _ in 0..<4 { native.enter(NativeC01TimingStandard.location, arriving: true) }
    let source = NativeC01TimingStandardSource(
      mission: UUID(), permission: UUID(), owner: UUID(), audit: UUID(), recorder: UUID(),
      anchors: try #require(native.anchors), reference: .init(), visit: 4, physicalTime: 50)
    self.source = source
    player = try #require(native.player)
    let group = try NativeC01TimingStandard.preparedEncounter(source)
    var target = try #require(group.actors[NativeC01TimingStandard.target])
    target.body.id = 10
    target.body.position = .init(0, -45, 55)
    target.presence = .present
    target.body.physical = .init(
      identity: .init(system: NativeC01TimingStandard.location, visit: 4, entity: 40),
      population: .mission,
      npc: .init(
        role: .mission, origin: NativeC01TimingStandard.location,
        destination: NativeC01TimingStandard.location))
    target.body.physical?.spawnIdentity = .init(
      system: NativeC01TimingStandard.location, visit: 4, sequence: 1, member: 0, producer: .mission
    )
    target.body.physical?.npc?.resources = .legacyEnergyOnly(
      maximumEnergy: NativeC01TimingStandard.Part.standard.profile.energy)
    marker = target
  }

  func capture(speed: Double = 0, revision: UInt64 = 4) throws -> NativeC01TimingStandardCapture {
    .init(
      operation: NativeC01TimingStandard.operation(source: source), source: source,
      missionRevision: revision, marker: marker, collector: player, carrier: carrier,
      inventoryRevision: 1,
      scoop: .init(
        id: UUID(), node: try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops")),
        location: .init(hull: carrier, slot: "utility.fuelScoops"),
        provenance: .grant("Unqualified C01 standard component facts")),
      point: marker.body.position, relativeSpeed: speed, startTime: 60, physicalTime: 60.05,
      epoch: UUID())
  }
}

private struct C01TimingStandardLossArchive: Codable {
  var standard: NativeC01TimingStandardState?
  var recorder: NativeC01SurveyorState?
}

struct NativeC01TimingStandardUnitTests {
  @Test(arguments: [0, 4, 9])
  func originalRecorderAndStandardUseTotalCapacityWithOnlyOneAdditionalFreeTonne(other: Int) throws
  {
    let before = try #require(
      NativeC01TimingStandard.cargoTonnes(
        otherCargo: other, storedKg: 8, addingStandard: false))
    let after = try #require(
      NativeC01TimingStandard.cargoTonnes(
        otherCargo: other, storedKg: 8, addingStandard: true))
    #expect(before == other + 1)
    #expect(after == other + 2)
    let insufficientTotalCapacity = other + 1
    let sufficientTotalCapacity = other + 2
    #expect(after > insufficientTotalCapacity)
    #expect(sufficientTotalCapacity - before == 1)
    #expect(after <= sufficientTotalCapacity)
    // 8kg recorder + 992kg other stored items share one rounded reservation.
    #expect(
      NativeC01TimingStandard.cargoTonnes(
        otherCargo: other, storedKg: 1000, addingStandard: true) == other + 2)
    #expect(
      NativeC01TimingStandard.cargoTonnes(
        otherCargo: other, storedKg: 1000.001, addingStandard: true) == other + 3)
    #expect(
      NativeC01TimingStandard.cargoTonnes(
        otherCargo: Int.max, storedKg: 8, addingStandard: true) == nil)
    for bad in [-1.0, .infinity, .nan] {
      #expect(
        NativeC01TimingStandard.cargoTonnes(otherCargo: other, storedKg: bad, addingStandard: true)
          == nil)
    }
  }

  @Test func sceneUsesDistinctOriginalActorsAndExplicitMetresWithoutMassScaling() throws {
    let facts = try C01TimingStandardFacts()
    let group = try NativeC01TimingStandard.preparedEncounter(facts.source)
    #expect(group.valid && !group.admitted)
    #expect(group.galaxy == 0 && group.system == 162)
    #expect(group.actors.count == 5)
    #expect(Set(group.actors.values.map(\.identity)).count == 5)
    #expect(NativeC01TimingStandard.Part.standard.design == (try NativeC01Props.standard.get()).nativeDesign)
    #expect(NativeC01TimingStandard.Part.standard.design != NativeC01SurveyorGeometry.recorder)
    #expect(NativeC01TimingStandard.Part.standard.massKg == 1000)
    #expect(NativeC01TimingStandard.Part.arm.dimensions == .init(120, 2, 2))
    let foreign = try C01TimingStandardFacts()
    for part in NativeC01TimingStandard.Part.allCases {
      let actor = try #require(group.actors[part.rawValue])
      #expect(NativeC01TimingStandard.original(actor, source: facts.source, part: part))
      #expect(!NativeC01TimingStandard.original(actor, source: foreign.source, part: part))
      let hull = try #require(NativeC01TimingStandard.hulls.get()[part])
      #expect(hull.isClosed)
      #expect(actor.presence == .prepared && actor.body.physical == nil)
    }
  }

  @Test func proposedArmAndSideCorridorRequireActualPlayerHullSweeps() throws {
    // Geometric expectations, UNRUN until the existing native executor runs them.
    // Even PASS would not establish the real Enlirin admission/capture/save journey.
    let player = try PreparedHull(mesh: Commander().playerMesh)
    let hulls = try NativeC01TimingStandard.hulls.get()
    let obstacles = try NativeC01TimingStandard.Part.allCases.map { part in
      HullSweepObstacle(hull: try #require(hulls[part]), pose: .init(position: part.centre))
    }
    func motion(_ start: Vector3, _ end: Vector3, orientation: Basis3 = .init()) -> HullSceneMotion
    {
      .init(
        start: .init(position: start, orientation: orientation),
        end: .init(position: end, orientation: orientation), initialVelocity: (end - start) * 0.05,
        acceleration: .init(0, 0, 0), worldAngularVelocity: .init(0, 0, 0),
        duration: 20, playerRadius: player.radius)
    }
    let blocked = HullSweepSafety.validateSceneMotion(
      motion(.init(0, 0, 250), .init(0, 0, -55)), player: player,
      obstacles: [
        .init(
          hull: try #require(hulls[.arm]),
          pose: .init(position: NativeC01TimingStandard.Part.arm.centre))
      ])
    #expect(!blocked.safe)
    #expect(blocked.failure == .insideHull || blocked.failure == .clearanceViolation)
    var side = Basis3()
    side.x = .init(0, 0, 1)
    side.y = .init(0, 1, 0)
    side.z = .init(-1, 0, 0)
    let end = Vector3(55, 45, 0)
    #expect((end + side.apply(.init(0, -45, 55))).length == 0)
    let clear = HullSweepSafety.validateSceneMotion(
      motion(end + .init(1000, 0, 0), end, orientation: side), player: player, obstacles: obstacles)
    #expect(clear.safe)
  }

  @Test func closedLoadRejectsUnknownMassForeignOperationAndOverspeedClaims() throws {
    let facts = try C01TimingStandardFacts()
    var state = NativeC01TimingStandardState(source: facts.source)
    state.capture = try facts.capture()
    #expect(NativeC01TimingStandardSave.shapeValid(state))
    #expect(state.heldMassKg == 1000)
    let data = try JSONEncoder().encode(state)
    #expect(try NativeC01TimingStandardSave.decodeClosed(data) == state)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["heldMassKg"] = 1000
    #expect(throws: (any Error).self) {
      try NativeC01TimingStandardSave.decodeClosed(JSONSerialization.data(withJSONObject: object))
    }
    object.removeValue(forKey: "heldMassKg")
    var capture = try #require(object["capture"] as? [String: Any])
    capture["operation"] = UUID().uuidString
    object["capture"] = capture
    #expect(throws: (any Error).self) {
      try NativeC01TimingStandardSave.decodeClosed(JSONSerialization.data(withJSONObject: object))
    }
    state.capture = try facts.capture(speed: 15.0001)
    #expect(!NativeC01TimingStandardSave.shapeValid(state))
    state.capture = try facts.capture(revision: UInt64.max)
    #expect(!NativeC01TimingStandardSave.shapeValid(state))
    let slowTurnAndSpin = try #require(
      NativeC01TimingStandard.approachSpeed(
        relativeVelocity: .init(2, 0, 0), playerAngularVelocity: .init(0, 0.01, 0),
        targetAngularVelocity: .init(0.1, 0, 0)))
    let radius = NativeC01TimingStandard.Part.standard.design.rawMesh.vertices.map(\.length).max()!
    #expect(slowTurnAndSpin > 2 && slowTurnAndSpin < 15)
    #expect(
      NativeC01Surveyor.approachAllowed(
        point: facts.marker.body.position, radius: radius, speed: slowTurnAndSpin))
    let tooFast = try #require(
      NativeC01TimingStandard.approachSpeed(
        relativeVelocity: .init(2, 0, 0), playerAngularVelocity: .init(0, 1, 0),
        targetAngularVelocity: .init(0.1, 0, 0)))
    #expect(
      !NativeC01Surveyor.approachAllowed(
        point: facts.marker.body.position, radius: radius, speed: tooFast))
  }

  @Test func originalSourceLossPersistsAndCannotAlsoClaimRecoveredCustody() throws {
    let facts = try C01TimingStandardFacts()
    var marker = facts.marker
    marker.presence = .destroyed
    marker.body.energy = 0
    var state = NativeC01TimingStandardState(source: facts.source)
    state.loss = .init(
      kind: .standardDestroyed, actor: marker, collector: facts.player, carrier: facts.carrier,
      energy: 100, escapePod: nil, physicalTime: 61)
    #expect(NativeC01TimingStandardSave.shapeValid(state))
    #expect(!state.held && state.heldMassKg == 0)
    #expect(try NativeC01TimingStandardSave.decodeClosed(JSONEncoder().encode(state)) == state)
    state.capture = try facts.capture()
    #expect(!NativeC01TimingStandardSave.shapeValid(state))
    state.loss = .init(
      kind: .carrierDestroyed, actor: nil, collector: facts.player, carrier: facts.carrier,
      energy: 0, escapePod: nil, physicalTime: 61)
    #expect(NativeC01TimingStandardSave.shapeValid(state))
    #expect(!state.held && state.capture != nil)
  }

  @Test func decodedAndDuplicateFactsCannotStartLiveObservationOrAdvanceTheRealPack() throws {
    let facts = try C01TimingStandardFacts()
    var game = Game(executive: false)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledGlassMeridianDirectory)]
    let commander = game.commander
    var state = NativeC01TimingStandardState(source: facts.source)
    #expect(game.beginC01TimingStandardObservation(state: state, delta: 0.05) == nil)
    #expect(game.beginC01TimingStandardObservation(state: state, delta: 0) == nil)
    #expect(NativeC01TimingStandard.source(in: game) == nil)
    state.capture = try facts.capture()
    let decoded = try NativeC01TimingStandardSave.decodeClosed(JSONEncoder().encode(state))
    for _ in 0..<2 {
      #expect(game.beginC01TimingStandardObservation(state: decoded, delta: 0.05) == nil)
      #expect(game.c01TimingStandardObservedLoss(current: decoded) == nil)
    }
    let foreign = ScriptInstance(
      id: facts.source.mission, definition: NativeGlassMeridian.stateID,
      version: NativeGlassMeridian.version, digest: NativeGlassMeridian.digest)
    #expect(!NativeC01TimingStandardSave.valid(decoded, mission: foreign, commander: commander))
    #expect(game.commander == commander)
    #expect(game.glassMeridianMission == nil)
  }
  @Test(arguments: [false, true])
  func carriedStandardLossRequiresBothOriginalArchiveRecords(escape: Bool) throws {
    let facts = try C01TimingStandardFacts()
    var standard = NativeC01TimingStandardState(source: facts.source)
    standard.capture = try facts.capture()
    var archive = C01TimingStandardLossArchive(
      standard: standard,
      recorder: try C01SurveyorFixture().held().surveyor)
    let pod: EquipmentPurchaseItem? =
      escape
      ? .init(
        id: UUID(),
        node: try #require(EquipmentRuntimeCatalog.node(for: "Escape Pod")),
        location: .init(hull: facts.carrier, slot: "utility.escapePod"),
        provenance: .grant("Paired loss component history")) : nil
    standard.loss = .init(
      kind: escape ? .escape : .carrierDestroyed, actor: nil,
      collector: facts.player, carrier: facts.carrier, energy: escape ? 100 : 0,
      escapePod: pod, physicalTime: 70)
    archive.standard = standard
    // The previously accepted standard-only mutation leaves the recorder held.
    #expect(archive.recorder?.held == true)
    #expect(!NativeC01TimingStandardSave.carrierLossJoins(standard, recorder: archive.recorder))
    archive.recorder?.loss = .init(
      kind: escape ? .escape : .carrierDestroyed,
      marker: nil, collector: facts.player, carrier: facts.carrier, energy: escape ? 100 : 0,
      escapePod: pod, physicalTime: 70)
    let bytes = try JSONEncoder().encode(archive)
    let paired = try JSONDecoder().decode(C01TimingStandardLossArchive.self, from: bytes)
    #expect(
      NativeC01TimingStandardSave.carrierLossJoins(
        try #require(paired.standard), recorder: paired.recorder))
    for field in ["carrier", "physicalTime", "energy", "kind", "collector"] {
      var raw = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
      var recorder = try #require(raw["recorder"] as? [String: Any])
      var loss = try #require(recorder["loss"] as? [String: Any])
      switch field {
      case "carrier": loss[field] = UUID().uuidString
      case "physicalTime": loss[field] = 71
      case "energy": loss[field] = 50
      case "kind": loss[field] = escape ? "carrierDestroyed" : "escape"
      default:
        var collector = try #require(loss[field] as? [String: Any])
        collector["entity"] = 1
        loss[field] = collector
      }
      recorder["loss"] = loss
      raw["recorder"] = recorder
      let corrupt = try JSONDecoder().decode(
        C01TimingStandardLossArchive.self,
        from: JSONSerialization.data(withJSONObject: raw))
      #expect(
        !NativeC01TimingStandardSave.carrierLossJoins(
          try #require(corrupt.standard), recorder: corrupt.recorder))
    }
    var missingStandardLoss = try #require(paired.standard)
    missingStandardLoss.loss = nil
    #expect(
      !NativeC01TimingStandardSave.carrierLossJoins(missingStandardLoss, recorder: paired.recorder))
    var independent = NativeC01TimingStandardState(source: facts.source)
    var destroyed = facts.marker
    destroyed.presence = .destroyed
    destroyed.body.energy = 0
    independent.loss = .init(
      kind: .standardDestroyed, actor: destroyed,
      collector: facts.player, carrier: facts.carrier, energy: 100, escapePod: nil, physicalTime: 70
    )
    #expect(NativeC01TimingStandardSave.shapeValid(independent))
    #expect(NativeC01TimingStandardSave.carrierLossJoins(independent, recorder: archive.recorder))
  }

}

// Real commission and Sorel dock/confirmation; controlled earlier scan/recorder history,
// Enlirin placement and owned tool setup. No claim that this fixture flew the earlier story.
private final class C01TimingStandardJourneyFixture {
  let root: URL
  let save: URL
  var game: Game

  init() async throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "c01-audit-" + UUID().uuidString)
    save = root.appendingPathComponent("commander.json")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    _ = try await runtime.registerNewCommanderDestination(at: save)
    game = await runtime.snapshot()
    game.screen = .status
    let owner = try #require(game.commander.equipmentOwnerID)
    for system in [185, 93] {
      let key = "main-orbital:0:\(system)"
      let identity = NativeMainStationIdentity(
        world: owner, system: .init(galaxy: 0, system: system),
        resource: Game.worldResourceIdentity("main-station-v1:" + key))
      game.commander.nativeStations?.mainStations.append(identity)
      game.commander.scriptState.stationResources[key] = .init(
        identity: identity.resource, galaxy: 0, system: system)
    }
    var discovery = NativeFleetDiscovery(owner: owner)
    let ships = ShipCatalogue.all.filter {
      $0.originalDefinition != nil && $0.catalogue.discoveryEligible
        && $0.catalogue.objectKind == .ship
        && !OriginalDetailedHullStage.blocksRuntime($0.id)
    }.prefix(2)
    try #require(ships.count == 2)
    for ship in ships {
      let allocated = game.commander.flightSimulation.allocateActor()
      let actor = try #require(allocated)
      let player = try #require(game.commander.flightSimulation.player)
      try discovery.record(
        .init(
          owner: owner, ship: ship.id, kind: .identification, actor: actor, player: player,
          physicalTime: 0, death: nil, mainDock: nil, secondaryDock: nil))
    }
    game.commander.scriptState.savedFleetDiscovery = discovery
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledGlassMeridianDirectory)]
    try #require(game.nativeMainStationDockEvidenceIsCurrent && game.scriptDurabilityAvailable)
    try #require(game.commander.valid)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func heldAtSorel() async throws -> GameRuntime {
    _ = try accept()
    let accepted = try #require(game.glassMeridianMission)
    let opening = try #require(accepted.savedGlassMeridian)
    let component = try C01SurveyorFixture(commission: opening)
    let held = try component.held()
    let history = try component.commander(held)
    var mission = accepted
    mission.savedGlassMeridian = held
    mission.milestones = [0, 1, 2]
    mission.revision += 2
    mission.ownedEncounters = try #require(history.scriptState.instances[mission.id])
      .ownedEncounters
    for sealed in held.readings {
      let ordinal = sealed.reading.ordinal
      let key = NativeGlassMeridian.encounters[ordinal]
      var group = ScriptOwnedEncounter(
        id: key, galaxy: 0, system: 185,
        actors: [NativeGlassMeridian.targets[ordinal]: sealed.authority.marker])
      group.admitted = true
      mission.ownedEncounters[key] = group
    }
    // The controlled earlier-system history has departed, just as native travel unloads
    // its present actors. Keep the captured recorder outside and retain every actor/proof.
    for key in mission.ownedEncounters.keys {
      guard var group = mission.ownedEncounters[key], group.galaxy != 0 || group.system != 0 else {
        continue
      }
      for alias in group.actors.keys where group.actors[alias]?.presence == .present {
        group.actors[alias]?.presence = .unloaded
      }
      mission.ownedEncounters[key] = group
    }
    game.commander.scriptState.instances[mission.id] = mission
    game.commander.scriptState.geometry.merge(history.scriptState.geometry) { existing, _ in
      existing
    }
    let pack = try #require(game.glassMeridianPack)
    for design in pack.models.values {
      let hash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
      game.commander.scriptState.geometry[hash] = design
    }
    game.commander.flightSimulation = history.flightSimulation
    game.commander.nativeStations?.currentMainDock = nil
    game.nativeMainStationDockEvidence = nil
    game.commander.system = 0
    game.selectedSystem = 0
    game.market = MarketItem.at(game.currentSystem)
    // Controlled Enmadan scene setup after the historical component proofs; no route claim.
    game.launch()
    try #require(!game.docked && game.commander.valid, Comment(rawValue: game.message))
    let station = try #require(game.bodies.first { $0.id == 0 })
    let old = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = old.orientation.apply(station.entranceUp)
    pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
    let runtime = GameRuntime(game: game, saveURL: save)
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    let review = arrived.glassMeridianReview(.auditReservations)
    try #require(review.allowed, Comment(rawValue: review.issues.joined(separator: "; ")))
    return runtime
  }

  func accept() throws -> NativeC01ReservationSource {
    let review = game.glassMeridianReview(.accept)
    try #require(review.allowed, Comment(rawValue: review.issues.joined(separator: "; ")))
    try game.confirmGlassMeridian(review)
    return try #require(game.glassMeridianMission?.savedGlassMeridian?.reservationCase?.source)
  }
  func atStandard(escapePod: Bool = false, admit: Bool = true) async throws -> Game {
    let runtime = try await heldAtSorel()
    let before = await runtime.snapshot()
    let review = before.glassMeridianReview(.auditReservations)
    try await runtime.scriptCommand { game in try game.confirmGlassMeridianReservationAudit(review)
    }
    var current = await runtime.snapshot()
    // Controlled scene travel must end the old ordinary population before changing
    // coordinates, using the same departure boundary as actual system travel.
    try current.departOrdinarySimulation()
    try #require(current.commander.npcPersistence.count == 0)
    current.commander.nativeStations?.currentMainDock = nil
    current.nativeMainStationDockEvidence = nil
    current.commander.system = 162
    current.selectedSystem = 162
    current.market = MarketItem.at(current.currentSystem)
    current.launch()
    try #require(current.commander.npcPersistence.count == 0
      || current.commander.npcPersistence.system == current.systemIdentity)
    current.speed = 0
    current.autoPilot.disengage()
    current.screen = .front
    let inventory = try #require(current.commander.equipmentInventory)
    if current.commander.fittedEquipment(at: .utility(.fuelScoops)) == nil {
      let scoop = OwnedEquipmentItem(
        id: UUID(),
        node: try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops")),
        provenance: .grant("C01 standard test-owned tool; not a campaign reward"),
        location: .init(hullInstanceID: inventory.activeHull, slot: .utility(.fuelScoops)))
      current.commander.savedEquipmentInventory = try .init(
        owner: inventory.owner,
        activeHull: inventory.activeHull, revision: inventory.revision + 1,
        items: inventory.items + [scoop])
    }
    if escapePod, current.commander.fittedEquipment(at: .utility(.escapePod)) == nil {
      let currentInventory = try #require(current.commander.equipmentInventory)
      let pod = OwnedEquipmentItem(
        id: UUID(),
        node: try #require(EquipmentRuntimeCatalog.node(for: "Escape Pod")),
        provenance: .grant("C01 paired escape test-owned tool"),
        location: .init(hullInstanceID: currentInventory.activeHull, slot: .utility(.escapePod)))
      current.commander.savedEquipmentInventory = try .init(
        owner: currentInventory.owner,
        activeHull: currentInventory.activeHull, revision: currentInventory.revision + 1,
        items: currentInventory.items + [pod])
    }
    let source = try #require(NativeC01TimingStandard.source(in: current))
    NativeStationTestFixture.reframe(
      &current, to: .init(position: source.position + .init(500, 45, 0)))
    if !admit { return current }
    let timingPrepared = try current.prepareC01TimingStandard()
    try #require(timingPrepared, Comment(rawValue: current.message))
    let leaf = try #require(current.glassMeridianMission?.savedGlassMeridian?.timingStandard)
    var side = Basis3()
    side.x = .init(0, 0, 1)
    side.y = .init(0, 1, 0)
    side.z = .init(-1, 0, 0)
    NativeStationTestFixture.reframe(
      &current,
      to: .init(position: leaf.source.position + .init(55, 45, 0), orientation: side))
    let target = try #require(current.c01TimingStandardActor(source: leaf.source, part: .standard))
    current.weaponsTargetID = target.body.id
    try #require(current.commander.valid)
    return current
  }

}

extension NativeC01TimingStandardUnitTests {
  @Test func actualAdmissionTurningSpinContactPublishesOneStandardAndReloads() async throws {
    let f = try await C01TimingStandardJourneyFixture()
    defer { f.clean() }
    var game = try await f.atStandard()
    let initial = try #require(game.glassMeridianMission)
    let source = try #require(initial.savedGlassMeridian?.timingStandard?.source)
    let target = try #require(game.c01TimingStandardActor(source: source, part: .standard))
    let index = try #require(game.bodies.firstIndex(where: { $0.id == target.body.id }))
    game.bodies[index].physical?.angularVelocity = .init(0, 0.1, 0)
    game.commander.scriptState.instances[initial.id]?.ownedEncounters[
      NativeC01TimingStandard.encounter]?
      .actors[NativeC01TimingStandard.target]?.body.physical?.angularVelocity = .init(0, 0.1, 0)
    game.weaponsTargetID = nil  // Manual fitted-Scoops contact needs no selected targeting object.
    let runtime = GameRuntime(game: game, saveURL: f.save)
    try await runtime.save(to: f.save)
    var controls = Controls()
    controls.yaw = 0.01
    await runtime.setControls(controls)
    _ = await runtime.advance(delta: 0.05)
    let after = await runtime.snapshot()
    let mission = try #require(after.glassMeridianMission)
    let leaf = try #require(mission.savedGlassMeridian?.timingStandard)
    let capture = try #require(leaf.capture)
    #expect(
      leaf.held && leaf.heldMassKg == 1000 && capture.relativeSpeed > 0
        && capture.relativeSpeed < 15)
    #expect(mission.milestones == [0, 1, 2, 3, 4])
    #expect(mission.receipts.contains(NativeC01TimingStandard.receipt))
    #expect(after.bodies.allSatisfy { $0.missionActorID != target.identity })
    #expect(
      mission.ownedEncounters[NativeC01TimingStandard.encounter]?.actors[
        NativeC01TimingStandard.target]?.presence == .outside)
    #expect(mission.savedGlassMeridian?.surveyor == initial.savedGlassMeridian?.surveyor)
    #expect(
      mission.savedGlassMeridian?.reservationCase == initial.savedGlassMeridian?.reservationCase)
    #expect(after.commander.credits == game.commander.credits)
    #expect(after.commander.checkedCargoTonnes == (game.commander.checkedCargoTonnes ?? 0) + 1)
    #expect(
      after.commander.scriptState.savedClueJournal == game.commander.scriptState.savedClueJournal)
    #expect(mission.completionReceipt == nil && mission.outcome == .active)
    _ = await runtime.advance(delta: 0.05)
    let replay = await runtime.snapshot()
    #expect(replay.glassMeridianMission?.savedGlassMeridian?.timingStandard == leaf)
    #expect(replay.glassMeridianMission?.revision == mission.revision)
    #expect(replay.glassMeridianMission?.receipts == mission.receipts)
    let pointer = try Data(contentsOf: f.save)
    #expect(try JSONDecoder().decode(ScriptSavePointer.self, from: pointer).schemaVersion == NativeC01ReservationAuditSave.version)
    let decoded = try ScriptSaveStore.read(pointer, from: f.save)
    #expect(decoded.0.scriptState.instances[mission.id]?.savedGlassMeridian?.timingStandard == leaf)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: f.save)
    let loaded = await cold.snapshot()
    #expect(loaded.glassMeridianMission?.savedGlassMeridian?.timingStandard == leaf)
    #expect(loaded.nativeC01TimingStandardPending == nil)
    #expect(loaded.commander.checkedCargoTonnes == after.commander.checkedCargoTonnes)
  }

  @Test func actualFullHoldAndFailedWriterRetainSourceBeforeFreshMotionRetry() async throws {
    let f = try await C01TimingStandardJourneyFixture()
    defer { f.clean() }
    var game = try await f.atStandard()
    let original = try #require(game.glassMeridianMission)
    let occupied = try #require(game.commander.checkedCargoTonnes)
    let free = game.commander.tradeCargoCapacity - occupied
    try #require(free >= 1)
    game.commander.cargo[0] += free
    let runtime = GameRuntime(game: game, saveURL: f.save)
    try await runtime.save(to: f.save)
    _ = await runtime.advance(delta: 0.05)
    let full = await runtime.snapshot()
    #expect(full.glassMeridianMission?.savedGlassMeridian == original.savedGlassMeridian)
    #expect(full.glassMeridianMission?.revision == original.revision)
    #expect(full.glassMeridianMission?.receipts == original.receipts)
    #expect(full.glassMeridianMission?.savedGlassMeridian?.timingStandard?.capture == nil)
    #expect(
      full.bodies.contains {
        $0.missionActorID
          == NativeC01TimingStandard.actor(
            source: original.savedGlassMeridian!.timingStandard!.source, part: .standard)
      })
    var oneFree = full
    oneFree.commander.cargo[0] -= 1
    #expect(oneFree.commander.tradeCargoCapacity - (oneFree.commander.checkedCargoTonnes ?? 0) == 1)
    let retry = GameRuntime(game: oneFree, saveURL: f.save)
    try await retry.save(to: f.save)
    let pointer = try Data(contentsOf: f.save)
    try FileManager.default.removeItem(at: f.save)
    try FileManager.default.createDirectory(at: f.save, withIntermediateDirectories: false)
    _ = await retry.advance(delta: 0.05)
    let refused = await retry.snapshot()
    #expect(refused.glassMeridianMission?.savedGlassMeridian == original.savedGlassMeridian)
    #expect(refused.glassMeridianMission?.revision == original.revision)
    #expect(refused.glassMeridianMission?.receipts == original.receipts)
    #expect(refused.commander.credits == oneFree.commander.credits)
    #expect(
      refused.commander.scriptState.savedClueJournal
        == oneFree.commander.scriptState.savedClueJournal)
    #expect(refused.glassMeridianMission?.savedGlassMeridian?.timingStandard?.heldMassKg == 0)
    try FileManager.default.removeItem(at: f.save)
    try pointer.write(to: f.save, options: .atomic)
    _ = await retry.advance(delta: 0.05)
    let received = await retry.snapshot()
    #expect(received.glassMeridianMission?.savedGlassMeridian?.timingStandard?.held == true)
    #expect(received.commander.checkedCargoTonnes == received.commander.tradeCargoCapacity)
    #expect(
      received.glassMeridianMission?.savedGlassMeridian?.surveyor
        == original.savedGlassMeridian?.surveyor)
  }

  @Test func genuinePostMotionTokenRejectsChangedEpochAndSourceRevision() async throws {
    let f = try await C01TimingStandardJourneyFixture()
    defer { f.clean() }
    var game = try await f.atStandard()
    game.tick(delta: 0.05, controls: Controls())
    let token = try #require(game.nativeC01TimingStandardPending)
    let current = try #require(game.glassMeridianMission?.savedGlassMeridian?.timingStandard)
    let before = game.commander
    var stale = game
    stale.nativeStationRuntimeEpoch = UUID()
    #expect(throws: (any Error).self) {
      try stale.c01TimingStandardCandidate(token, current: current)
    }
    var revised = game
    let id = try #require(game.glassMeridianMission?.id)
    revised.commander.scriptState.instances[id]?.revision += 1
    #expect(throws: (any Error).self) {
      try revised.c01TimingStandardCandidate(token, current: current)
    }
    #expect(game.commander == before)
    #expect(current.capture == nil && current.heldMassKg == 0)
    #expect(game.c01TimingStandardActor(source: current.source, part: .standard) != nil)
  }

  @Test func currentEnvelopeRejectsNullMisplacedAndEmbeddedClaims() throws {
    let facts = try C01TimingStandardFacts()
    var opening = try C01SurveyorFixture().held()
    opening.timingStandard = .init(source: facts.source)
    let object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(opening)) as? [String: Any])
    let mission: [String: Any] = [
      "definition": NativeGlassMeridian.stateID,
      "version": NativeGlassMeridian.version, "digest": NativeGlassMeridian.digest,
      "savedGlassMeridian": object,
    ]
    let root: [String: Any] = ["instances": [UUID().uuidString: mission]]
    let bytes = try JSONSerialization.data(withJSONObject: root)
    for schema in [NativeC01ReservationAuditSave.version, NativeC01ReservationAuditSave.alienVersion] {
      try NativeC01TimingStandardSave.validateFields(bytes, part: .missions, schema: schema)
    }
    for schema in [139, 140] {
      #expect(throws: (any Error).self) {
        try NativeC01TimingStandardSave.validateFields(bytes, part: .missions, schema: schema)
      }
    }
    let wrongClaims: [Any] = [NSNull(), "wrong-type", 1]
    for claim in wrongClaims {
      var changed = object
      changed["timingStandard"] = claim
      var bad = mission
      bad["savedGlassMeridian"] = changed
      let raw = try JSONSerialization.data(withJSONObject: ["instances": [UUID().uuidString: bad]])
      for schema in [NativeC01ReservationAuditSave.version, NativeC01ReservationAuditSave.alienVersion] {
        #expect(throws: (any Error).self) {
          try NativeC01TimingStandardSave.validateFields(raw, part: .missions, schema: schema)
        }
      }
    }
    for raw in [
      ["timingStandard": NSNull()],
      ["instances": [UUID().uuidString: ["timingStandard": NSNull()]]],
      ["savedScriptState": root],
    ] as [[String: Any]] {
      #expect(throws: (any Error).self) {
        try NativeC01TimingStandardSave.validateFields(
          JSONSerialization.data(withJSONObject: raw),
          part: .commander, schema: NativeC01ReservationAuditSave.alienVersion)
      }
    }
  }
}

extension NativeC01TimingStandardUnitTests {
  @Test(arguments: [false, true])
  func actualPairedCarrierLossRejectsEitherMissingOriginalLoss(escape: Bool) async throws {
    let f = try await C01TimingStandardJourneyFixture()
    defer { f.clean() }
    let game = try await f.atStandard(escapePod: escape)
    let runtime = GameRuntime(game: game, saveURL: f.save)
    try await runtime.save(to: f.save)
    _ = await runtime.advance(delta: 0.05)
    let held = await runtime.snapshot()
    try #require(held.glassMeridianMission?.savedGlassMeridian?.timingStandard?.held == true)
    if escape {
      await runtime.escapeTimingStandardForTest()
    } else {
      await runtime.destroyTimingStandardCarrierForTest()
    }
    let lost = await runtime.snapshot()
    let mission = try #require(lost.glassMeridianMission)
    let opening = try #require(mission.savedGlassMeridian)
    let leaf = try #require(opening.timingStandard)
    let recorder = try #require(opening.surveyor)
    #expect(leaf.loss != nil && recorder.loss != nil && !leaf.held && !recorder.held)
    #expect(NativeC01TimingStandardSave.carrierLossJoins(leaf, recorder: recorder))
    #expect(NativeGlassMeridianSave.validateClaims(lost.commander))
    #expect(lost.commander.credits == held.commander.credits)
    #expect(
      lost.commander.scriptState.savedClueJournal == held.commander.scriptState.savedClueJournal)
    try await runtime.save(to: f.save)
    let pointer = try Data(contentsOf: f.save)
    let decoded = try ScriptSaveStore.read(pointer, from: f.save)
    #expect(decoded.0.scriptState.instances[mission.id]?.savedGlassMeridian == opening)
    for removeRecorder in [false, true] {
      var forged = lost
      if removeRecorder {
        forged.commander.scriptState.instances[mission.id]?.savedGlassMeridian?.surveyor?.loss = nil
      } else {
        forged.commander.scriptState.instances[mission.id]?.savedGlassMeridian?.timingStandard?
          .loss = nil
      }
      #expect(!NativeGlassMeridianSave.validateClaims(forged.commander))
      let refused = GameRuntime(game: forged, saveURL: f.save)
      do {
        try await refused.save(to: f.save)
        Issue.record("An archive missing one original carrier-loss record must refuse publication")
      } catch {}
      #expect(try Data(contentsOf: f.save) == pointer)
    }
  }
}

extension GameRuntime {
  fileprivate func destroyTimingStandardCarrierForTest() {
    game.energy = 0
    game.screen = .gameOver
    commitC01Surveyor(
      startTime: game.commander.flightSimulation.physicalTime,
      startPlayer: game.commander.flightSimulation.player)
    commitC01TimingStandard()
  }
  fileprivate func escapeTimingStandardForTest() { game.escapePod() }
}

extension NativeC01TimingStandardUnitTests {
  @Test func actualPreparedCohortAdmitsAllFiveOriginalParts() async throws {
    let fixture = try await C01TimingStandardJourneyFixture()
    defer { fixture.clean() }
    let game = try await fixture.atStandard()
    let mission = try #require(game.glassMeridianMission)
    let leaf = try #require(mission.savedGlassMeridian?.timingStandard)
    let group = try #require(mission.ownedEncounters[NativeC01TimingStandard.encounter])
    #expect(group.admitted)
    #expect(group.actors.count == NativeC01TimingStandard.Part.allCases.count)
    var physical: Set<ActorIdentity> = []
    for part in NativeC01TimingStandard.Part.allCases {
      let actor = try #require(game.c01TimingStandardActor(source: leaf.source, part: part))
      #expect(actor.presence == .present)
      let native = try #require(actor.body.physical)
      #expect(physical.insert(native.identity).inserted)
      #expect(native.spawnIdentity?.producer == .mission)
      #expect(game.bodies.filter { $0.missionActorID == actor.identity }.count == 1)
    }
    #expect(physical.count == 5)
    #expect(leaf.capture == nil && leaf.loss == nil)
    #expect(mission.milestones == [0, 1, 2, 3])
  }

  @Test func foreignPreparedActorRefusesWithoutPartialCohortOrAllocation() async throws {
    let fixture = try await C01TimingStandardJourneyFixture()
    defer { fixture.clean() }
    var game = try await fixture.atStandard(admit: false)
    let source = try #require(NativeC01TimingStandard.source(in: game))
    var mission = try #require(game.glassMeridianMission)
    var opening = try #require(mission.savedGlassMeridian)
    opening.timingStandard = .init(source: source)
    mission.savedGlassMeridian = opening
    var group = try NativeC01TimingStandard.preparedEncounter(source)
    mission.ownedEncounters[group.id] = group
    game.commander.scriptState.instances[mission.id] = mission
    let hashes = try NativeC01TimingStandard.modelHashes.get()
    for part in NativeC01TimingStandard.Part.allCases {
      game.commander.scriptState.geometry[try #require(hashes[part])] = part.design
    }
    let pack = try #require(game.glassMeridianPack)
    let originalAdmission = try game.c01TimingStandardAdmissionSource(
      pack: pack, state: mission, encounter: group)
    switch try game.prepareMissionActorAdmission(originalAdmission) {
    case .ready(let plan):
      #expect(plan.sceneBodyIDs.count == NativeC01TimingStandard.Part.allCases.count)
    default:
      Issue.record("The original cohort must prepare before testing a foreign actor.")
      return
    }
    let alias = NativeC01TimingStandard.Part.right.rawValue
    let original = try #require(group.actors[alias])
    let foreign = UUID()
    var body = original.body
    body.missionActorID = foreign
    group.actors[alias] = .init(
      identity: foreign, alias: alias, body: body, presence: .prepared)
    mission.ownedEncounters[group.id] = group
    game.commander.scriptState.instances[mission.id] = mission
    let bodyIDs = game.bodies.map(\.id)
    let nextActor = game.commander.flightSimulation.nextActor
    let nextSpawn = game.commander.flightSimulation.nextSpawn
    #expect(throws: (any Error).self) {
      let admission = try game.c01TimingStandardAdmissionSource(
        pack: pack, state: mission, encounter: group)
      _ = try game.prepareMissionActorAdmission(admission)
    }
    #expect(game.bodies.map(\.id) == bodyIDs)
    #expect(game.commander.flightSimulation.nextActor == nextActor)
    #expect(game.commander.flightSimulation.nextSpawn == nextSpawn)
    #expect(game.commander.scriptState.instances[mission.id] == mission)
    #expect(!group.admitted)
  }
}

// Storage-only values below publish no recovery authority or live pickup token.
extension NativeC01TimingStandardUnitTests {
  @Test func timingLeafCopiesDetachAllOptionalRecordsAndKeepHeldMass() throws {
    let facts = try C01TimingStandardFacts()
    let capture = try facts.capture()
    let loss = NativeC01TimingStandardLoss(
      kind: .carrierDestroyed, actor: nil, collector: facts.player, carrier: facts.carrier,
      energy: 0, escapePod: nil, physicalTime: 61)
    let used = NativeC01TimingStandardUse(
      operation: UUID(), mission: facts.source.mission, permission: facts.source.permission,
      owner: facts.source.owner, standard: capture.operation, recorder: facts.source.recorder,
      calibrations: [UUID(), UUID(), UUID()], sequence: 1, physicalTime: 61)
    let original = NativeC01TimingStandardState(
      source: facts.source, capture: capture, loss: loss, used: used)
    let retained = original
    var changed = original
    changed.capture = nil
    changed.loss = nil
    changed.used = nil
    #expect(original == retained && original.capture == capture)
    #expect(original.loss == loss && original.used == used && !original.held)
    #expect(changed != original && changed.source == original.source)
    #expect(!changed.held && changed.heldMassKg == 0)
    changed.capture = capture
    #expect(changed.held && changed.heldMassKg == 1000)
    changed.loss = loss
    #expect(!changed.held && changed.heldMassKg == 0)
    changed.used = used
    #expect(changed == original)
  }

  @Test func timingLeafThrowingModifyKeepsOnlyTheWritableCopyChanged() throws {
    enum Expected: Error { case stop }
    func clearThenThrow(_ value: inout NativeC01TimingStandardState) throws {
      value.capture = nil
      throw Expected.stop
    }
    let facts = try C01TimingStandardFacts()
    let original = NativeC01TimingStandardState(source: facts.source, capture: try facts.capture())
    let retained = original
    var changed = original
    #expect(throws: Expected.self) { try clearThenThrow(&changed) }
    #expect(changed.capture == nil && !changed.held)
    #expect(original == retained && original.capture != nil && original.held)
    changed.capture = original.capture
    #expect(changed == original)
  }

  @Test func timingLeafDirectCodecKeepsOptionalOmissionNullAndRequiredSource() throws {
    struct DirectFields: Codable {
      let source: NativeC01TimingStandardSource
      var capture: NativeC01TimingStandardCapture?
      var loss: NativeC01TimingStandardLoss?
      var used: NativeC01TimingStandardUse?
    }
    let facts = try C01TimingStandardFacts()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let decoder = JSONDecoder()
    for capture in [nil, try facts.capture()] {
      let original = NativeC01TimingStandardState(source: facts.source, capture: capture)
      let data = try encoder.encode(original)
      #expect(data == (try encoder.encode(DirectFields(source: facts.source, capture: capture))))
      #expect(try decoder.decode(NativeC01TimingStandardState.self, from: data) == original)
      var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      #expect(Set(object.keys) == (capture == nil ? ["source"] : ["source", "capture"]))
      #expect(object["storage"] == nil && object["value"] == nil)
      if capture == nil { object["capture"] = NSNull() }
      object["loss"] = NSNull()
      object["used"] = NSNull()
      let nulls = try JSONSerialization.data(withJSONObject: object)
      let decoded = try decoder.decode(NativeC01TimingStandardState.self, from: nulls)
      #expect(decoded == original)
      #expect(try encoder.encode(decoded) == data)
      object.removeValue(forKey: "source")
      #expect(throws: (any Error).self) {
        try decoder.decode(
          NativeC01TimingStandardState.self,
          from: JSONSerialization.data(withJSONObject: object))
      }
      object["source"] = NSNull()
      #expect(throws: (any Error).self) {
        try decoder.decode(
          NativeC01TimingStandardState.self,
          from: JSONSerialization.data(withJSONObject: object))
      }
      #expect(throws: (any Error).self) {
        try decoder.decode(
          NativeC01TimingStandardState.self,
          from: JSONSerialization.data(withJSONObject: ["storage": [object]]))
      }
    }
    let populated = NativeC01TimingStandardState(
      source: facts.source, capture: try facts.capture(),
      loss: .init(
        kind: .carrierDestroyed, actor: facts.marker, collector: facts.player,
        carrier: facts.carrier, energy: 0, escapePod: nil, physicalTime: 61),
      used: .init(
        operation: UUID(), mission: facts.source.mission, permission: facts.source.permission,
        owner: facts.source.owner, standard: UUID(), recorder: facts.source.recorder,
        calibrations: [UUID()], sequence: 1, physicalTime: 61))
    let populatedData = try encoder.encode(populated)
    #expect(populatedData == (try encoder.encode(DirectFields(
      source: populated.source, capture: populated.capture, loss: populated.loss,
      used: populated.used))))
    #expect(try decoder.decode(NativeC01TimingStandardState.self, from: populatedData) == populated)
  }

  @Test func timingLeafValueEqualityPreservesCopiedNaNAndSignedZero() throws {
    let facts = try C01TimingStandardFacts()
    func source(at time: Double) -> NativeC01TimingStandardSource {
      let value = facts.source
      return .init(
        mission: value.mission, permission: value.permission, owner: value.owner,
        audit: value.audit, recorder: value.recorder, anchors: value.anchors,
        reference: value.reference, visit: value.visit, physicalTime: time)
    }
    let nan = NativeC01TimingStandardState(source: source(at: .nan))
    let copiedNaN = nan
    #expect(nan != copiedNaN && nan.source.physicalTime.isNaN)
    let positive = NativeC01TimingStandardState(source: source(at: 0.0))
    let negative = NativeC01TimingStandardState(source: source(at: -0.0))
    #expect(positive == negative)
    #expect(positive.source.physicalTime.sign == .plus)
    #expect(negative.source.physicalTime.sign == .minus)
  }
}

// Native receipt producers share the ordinary current-save local-ID contract.
extension NativeC01TimingStandardUnitTests {
  @Test func currentC01TimingAndRelayReceiptMarkersAreDistinctValidLocalIDs() {
    let timing = [
      NativeC01TimingStandard.target, "recover-standard", NativeC01TimingStandard.receipt,
    ]
    let relayTargets = NativeC01LaneRepair.Target.allCases.map {
      NativeC01LaneRepair.receipt + "." + $0.rawValue
    }
    let lane = [NativeC01LaneRepair.receipt, "rebuild-lane"] + relayTargets
    #expect(timing.count == 3 && Set(timing).count == 3)
    #expect(relayTargets.count == 3 && Set(relayTargets).count == 3)
    #expect(lane.count == 5 && Set(lane).count == 5)
    #expect(Set(timing + lane).count == 8)
    for marker in timing + lane {
      #expect(PackValidation.localID(marker))
    }
  }
}

// Current structural values only; these checks create no actor or capture authority.
extension NativeC01TimingStandardUnitTests {
  @Test func ownedActorCopiesDetachNestedBodyAndRetainIdentityAndLocation() throws {
    let facts = try C01TimingStandardFacts()
    let original = facts.marker
    let originallyValid = original.valid
    let bindingValid = NativeC01TimingStandard.original(
      original, source: facts.source, part: .standard)
    #expect(originallyValid && bindingValid)
    let retained = original
    var changed = original
    changed.body.energy = 0
    changed.body.physical?.velocity.x = 4
    changed.presence = .destroyed
    changed.destroyedByPlayer = true
    changed.transitLocation = .init(galaxy: 0, system: 91)
    #expect(original == retained && changed != original)
    #expect(changed.identity == original.identity && changed.alias == original.alias)
    #expect(original.body.energy > 0 && original.presence == .present)
    #expect(original.body.physical?.velocity.x == 0)
    #expect(original.destroyedByPlayer == nil && original.transitLocation == nil)
    let encounter = ScriptOwnedEncounter(
      id: "storage-check", galaxy: 0, system: 162, actors: [original.alias: original])
    let originalLocation = original.location(in: encounter)
    let changedLocation = changed.location(in: encounter)
    let expectedOriginal = SystemIdentity(galaxy: 0, system: 162)
    let expectedChanged = SystemIdentity(galaxy: 0, system: 91)
    #expect(originalLocation == expectedOriginal && changedLocation == expectedChanged)
    changed.body = original.body
    changed.presence = original.presence
    changed.destroyedByPlayer = original.destroyedByPlayer
    changed.transitLocation = original.transitLocation
    #expect(changed == original)
  }

  @Test func ownedActorThrowingNestedBodyModifyDetachesWithoutRollingBackItsCopy() throws {
    enum Expected: Error { case stop }
    func editThenThrow(_ body: inout SpaceBody) throws {
      body.energy = 0
      body.physical?.velocity.y = 3
      throw Expected.stop
    }
    let original = try C01TimingStandardFacts().marker
    var changed = original
    var threwExpected = false
    do { try editThenThrow(&changed.body) }
    catch Expected.stop { threwExpected = true }
    #expect(threwExpected)
    #expect(changed.body.energy == 0 && changed.body.physical?.velocity.y == 3)
    #expect(original.body.energy > 0 && original.body.physical?.velocity.y == 0)
    changed.body = original.body
    #expect(changed == original)
  }

  @Test func ownedActorDirectCodecPreservesSixFieldsOptionalNullAndRequiredKeys() throws {
    struct DirectFields: Codable {
      let identity: UUID
      let alias: String
      var body: SpaceBody
      var presence: ScriptActorPresence
      var destroyedByPlayer: Bool?
      var transitLocation: SystemIdentity?
    }
    let original = try C01TimingStandardFacts().marker
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let decoder = JSONDecoder()
    func rejects(_ data: Data) -> Bool {
      do { _ = try decoder.decode(ScriptOwnedActor.self, from: data); return false }
      catch { return true }
    }
    for populated in [false, true] {
      var value = original
      if populated {
        value.destroyedByPlayer = false
        value.transitLocation = .init(galaxy: 0, system: 91)
      }
      let bytes = try encoder.encode(value)
      let direct = DirectFields(
        identity: value.identity, alias: value.alias, body: value.body, presence: value.presence,
        destroyedByPlayer: value.destroyedByPlayer, transitLocation: value.transitLocation)
      let directBytes = try encoder.encode(direct)
      let decoded = try decoder.decode(ScriptOwnedActor.self, from: bytes)
      #expect(bytes == directBytes && decoded == value)
      var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
      let keys = Set(object.keys)
      let expected: Set<String> = populated
        ? ["identity", "alias", "body", "presence", "destroyedByPlayer", "transitLocation"]
        : ["identity", "alias", "body", "presence"]
      #expect(keys == expected)
      #expect(object["storage"] == nil && object["value"] == nil)
      if !populated {
        object["destroyedByPlayer"] = NSNull()
        object["transitLocation"] = NSNull()
        let nullBytes = try JSONSerialization.data(withJSONObject: object)
        let nullDecoded = try decoder.decode(ScriptOwnedActor.self, from: nullBytes)
        let reencoded = try encoder.encode(nullDecoded)
        #expect(nullDecoded == value && reencoded == bytes)
      }
      for required in ["identity", "alias", "body", "presence"] {
        var missing = object
        missing.removeValue(forKey: required)
        let missingRejected = rejects(try JSONSerialization.data(withJSONObject: missing))
        missing[required] = NSNull()
        let nullRejected = rejects(try JSONSerialization.data(withJSONObject: missing))
        #expect(missingRejected && nullRejected)
      }
      let wrapperRejected = rejects(
        try JSONSerialization.data(withJSONObject: ["storage": [object]]))
      #expect(wrapperRejected)
    }
  }

  @Test func ownedActorBackingValueEqualityKeepsNaNAndSignedZeroSemantics() throws {
    let original = try C01TimingStandardFacts().marker
    var nan = original
    nan.body.energy = .nan
    let copiedNaN = nan
    #expect(nan != copiedNaN && nan.body.energy.isNaN)
    var positive = original
    var negative = original
    positive.body.position.x = 0.0
    negative.body.position.x = -0.0
    #expect(positive == negative)
    #expect(positive.body.position.x.sign == .plus)
    #expect(negative.body.position.x.sign == .minus)
  }
}


extension NativeC01TimingStandardUnitTests {
  @Test(arguments: ["valid", "alias", "actor-identity", "position-finite", "position-bound",
    "orientation", "energy-finite", "energy-bound", "npc", "rotation", "rotation-rate",
    "missiles", "body-id", "destroyed-presence", "mission-binding", "hull", "hostility", "ecm",
    "profile", "models"])
  func completeBorrowedActorReadPreservesEveryTimingPredicateAndOriginalValue(_ change: String)
    throws
  {
    // Component facts are not an authenticated mission or a live native capability.
    let facts = try C01TimingStandardFacts()
    let originalBytes = try JSONEncoder().encode(facts.marker)
    var candidate = facts.marker
    switch change {
    case "valid": break
    case "alias":
      candidate = .init(identity: candidate.identity, alias: "invalid alias",
        body: candidate.body, presence: candidate.presence)
    case "actor-identity": candidate.body.missionActorID = UUID()
    case "position-finite": candidate.body.position.x = .nan
    case "position-bound": candidate.body.position = .init(1_000_000_001, 0, 0)
    case "orientation": candidate.body.orientation.x = .init(0, 0, 0)
    case "energy-finite": candidate.body.energy = .nan
    case "energy-bound": candidate.body.energy = 10_000_001
    case "npc": candidate.body.scriptNPC?.fuel = .nan
    case "rotation": candidate.body.rotation = .infinity
    case "rotation-rate": candidate.body.rotationRate = .infinity
    case "missiles": candidate.body.missiles = 33
    case "body-id": candidate.body.id = -2
    case "destroyed-presence": candidate.presence = .destroyed
    case "mission-binding": candidate.body.missionInstanceID = UUID()
    case "hull": candidate.body.hull = .station
    case "hostility": candidate.body.hostile = true
    case "ecm": candidate.body.ecmEnabled = true
    case "profile": candidate.body.scriptNPC = nil
    case "models":
      candidate.body.scriptNPC = .init(
        fit: .init(definition: NativeC01TimingStandard.Part.standard.profile, models: [:]),
        fuel: 0, guns: [:], components: [:])
    default: Issue.record("Unknown actor validation case"); return
    }
    let accepted = NativeC01TimingStandard.original(candidate, source: facts.source, part: .standard)
    #expect(accepted == (change == "valid"))
    if ["alias", "actor-identity", "position-finite", "position-bound", "orientation",
      "energy-finite", "energy-bound", "npc", "rotation", "rotation-rate", "missiles", "body-id",
      "destroyed-presence"].contains(change)
    {
      let generallyValid = candidate.valid
      #expect(!generallyValid)
    }
    let originalStillValid = NativeC01TimingStandard.original(
      facts.marker, source: facts.source, part: .standard)
    #expect(originalStillValid)
    let retainedBytes = try JSONEncoder().encode(facts.marker)
    #expect(retainedBytes == originalBytes)
    let decoded = try JSONDecoder().decode(ScriptOwnedActor.self, from: originalBytes)
    #expect(decoded == facts.marker)
  }
}
