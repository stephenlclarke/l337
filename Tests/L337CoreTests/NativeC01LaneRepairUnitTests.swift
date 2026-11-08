import Foundation
import Testing

@testable import L337Core

// Controlled earlier history and placement; actual pickup, input and elapsed work run below.
final class C01LaneRepairJourneyFixture {
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

extension C01LaneRepairJourneyFixture {
  func atRelays() async throws -> Game {
    let pickup = GameRuntime(game: try await atStandard(), saveURL: save)
    try await pickup.save(to: save)
    _ = await pickup.advance(delta: 0.05)
    var current = await pickup.snapshot()
    try #require(current.glassMeridianMission?.savedGlassMeridian?.timingStandard?.held == true)
    current.commander.nativeStations?.currentMainDock = nil
    current.nativeMainStationDockEvidence = nil
    // Controlled scene transition, not a flown route or mission completion claim.
    let standardOperation = try #require(current.glassMeridianMission?
      .savedGlassMeridian?.timingStandard?.capture?.operation)
    let recorderOperation = try #require(current.glassMeridianMission?
      .savedGlassMeridian?.surveyor?.capture?.operation)
    // Freeze the outgoing mission actors while their actual source system and frame
    // are still current, in the same order as the normal travel boundary.
    current.persistScriptActors(unloading: true)
    let outgoing = try #require(current.glassMeridianMission?
      .ownedEncounters[NativeC01TimingStandard.encounter])
    try #require(outgoing.actors.values.allSatisfy { $0.presence != .present })
    try #require(outgoing.actors[NativeC01TimingStandard.target]?.presence == .outside)
    try #require(current.glassMeridianMission?.savedGlassMeridian?
      .timingStandard?.capture?.operation == standardOperation)
    try #require(current.glassMeridianMission?.savedGlassMeridian?
      .surveyor?.capture?.operation == recorderOperation)
    try current.departOrdinarySimulation()
    try #require(current.commander.npcPersistence.count == 0)
    current.commander.system = 91
    current.selectedSystem = 91
    current.market = MarketItem.at(current.currentSystem)
    current.launch()
    try #require(current.commander.npcPersistence.count == 0
      || current.commander.npcPersistence.system == current.systemIdentity)
    current.speed = 0
    current.autoPilot.disengage()
    current.screen = .front
    let lanePrepared = try current.prepareC01LaneRepair()
    try #require(lanePrepared)
    try #require(current.commander.valid)
    return current
  }

  func park(_ game: inout Game, at target: NativeC01LaneRepair.Target) throws {
    let source = try #require(game.glassMeridianMission?.savedGlassMeridian?.laneRepair?.source)
    let actor = try #require(game.c01LaneRepairActor(source: source, target: target))
    let face = try NativeC01Props.relay.get().interactionFace
    let pose = game.modelPose(of: actor.body)
    let normal = pose.orientation.apply(face.outward)
    var facing = Basis3()
    facing.y = pose.orientation.apply(face.up)
    facing.z = normal * -1
    facing.x = facing.y.cross(facing.z)
    NativeStationTestFixture.reframe(&game, to: .init(
      position: pose.systemPoint(face.center) + normal * 100, orientation: facing))
    game.speed = 0
    game.autoPilot.disengage()
    game.weaponsTargetID = actor.body.id
  }

  func runtime(at target: NativeC01LaneRepair.Target, game: Game) async throws -> GameRuntime {
    var positioned = game
    try park(&positioned, at: target)
    let runtime = GameRuntime(game: positioned, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("return")
    try #require(await runtime.snapshot().c01LaneRepairWorkRuntime.review != nil)
    await runtime.key("return")
    try #require(await runtime.snapshot().c01LaneRepairWorkRuntime.arm != nil)
    return runtime
  }

  /// Full work follows the qualified clock and the same live target's real receipt.
  /// Elapsed advances can include intervals that do not qualify as calibration time.
  func work(_ runtime: GameRuntime) async {
    let optionalBinding = await runtime.snapshot().c01LaneRepairWorkRuntime.arm?.binding
    #expect(optionalBinding != nil)
    guard let binding = optionalBinding else { return }
    let credited = await runtime.snapshot().glassMeridianMission?.savedGlassMeridian?
      .laneRepair?.progress.first(where: { $0.target == binding.target })?.seconds
    #expect(credited != nil)
    guard let credited, credited.isFinite,
      (0...NativeC01LaneRepair.qualifiedSeconds).contains(credited)
    else { return }
    let step = 0.05
    let required = Int(ceil((NativeC01LaneRepair.qualifiedSeconds - credited) / step))
    let confirmation = Int(ceil(NativeC01LaneRepair.maximumPhysicalInterval / step)) + 1
    for _ in 0..<(required + confirmation) {
      let current: Bool
      do {
        let snapshot = await runtime.snapshot()
        let mission = snapshot.glassMeridianMission
        if mission?.id == binding.mission,
          mission?.savedGlassMeridian?.laneRepair?.receipts.contains(where: {
            $0.target == binding.target && $0.confirmation.arm == binding
          }) == true
        { return }
        current = mission?.id == binding.mission
          && snapshot.c01LaneRepairWorkRuntime.arm?.binding == binding
          && snapshot.nativeStationRuntimeEpoch == binding.epoch
      }
      guard current else { break }
      await work(runtime, intervals: 1)
    }
    let snapshot = await runtime.snapshot()
    let state = snapshot.glassMeridianMission?.savedGlassMeridian?.laneRepair
    let progress = state?.progress.first { $0.target == binding.target }
    let received = snapshot.glassMeridianMission?.id == binding.mission
      && state?.receipts.contains(where: {
        $0.target == binding.target && $0.confirmation.arm == binding
      }) == true
    let evidence = "target=\(binding.target.rawValue) qualified=\(progress?.seconds ?? -1)"
      + " intervals=\(progress?.segments.reduce(0) { $0 + $1.intervals } ?? 0)"
      + " reason=\(snapshot.c01LaneRepairWorkRuntime.reason.prefix(128))"
    #expect(received, Comment(rawValue: evidence))
  }

  /// This caller has already blocked the real save destination. Measure the same
  /// outer target to20 qualified seconds and prove a fresh completion was refused.
  func completeOuterWorkWithWriterBlocked(_ runtime: GameRuntime) async throws {
    var directory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: save.path, isDirectory: &directory)
    try #require(exists && directory.boolValue)
    let binding = try #require(await runtime.snapshot().c01LaneRepairWorkRuntime.arm?.binding)
    try #require(binding.target == .outer)
    let credited = try #require(await runtime.snapshot().glassMeridianMission?
      .savedGlassMeridian?.laneRepair?.progress.first(where: { $0.target == .outer })?.seconds)
    let previousIntervals = try #require(await runtime.snapshot().glassMeridianMission?
      .savedGlassMeridian?.laneRepair?.progress.first(where: { $0.target == .outer })?
      .segments.last?.intervals)
    try #require(credited.isFinite && credited >= 0
      && credited < NativeC01LaneRepair.qualifiedSeconds - 1e-8)
    let step = 0.05
    let required = Int(ceil((NativeC01LaneRepair.qualifiedSeconds - credited) / step))
    let confirmation = Int(ceil(NativeC01LaneRepair.maximumPhysicalInterval / step)) + 1
    for _ in 0..<(required + confirmation) {
      await work(runtime, intervals: 1)
      let snapshot = await runtime.snapshot()
      try #require(snapshot.glassMeridianMission?.id == binding.mission
        && snapshot.c01LaneRepairWorkRuntime.arm?.binding == binding
        && snapshot.nativeStationRuntimeEpoch == binding.epoch)
      let state = try #require(snapshot.glassMeridianMission?.savedGlassMeridian?.laneRepair)
      let progress = try #require(state.progress.first { $0.target == .outer })
      if abs(progress.seconds - NativeC01LaneRepair.qualifiedSeconds) < 1e-8 {
        let last = try #require(progress.segments.last)
        try #require(last.last == snapshot.commander.flightSimulation.physicalTime
          && last.intervals > previousIntervals)
        try #require(state.receipts.count == 2 && state.installation == nil)
        try #require(snapshot.glassMeridianMission?.savedGlassMeridian?.timingStandard?.held == true)
        try #require(NativeC01LaneRepairSave.shapeValid(state))
        try #require(snapshot.c01LaneRepairWorkRuntime.reason
          == "MEASURED WORK RETAINED - SAVE PENDING; ORIGINAL STANDARD AND STAGE NOT COMMITTED")
        return
      }
    }
    let snapshot = await runtime.snapshot()
    let seconds = snapshot.glassMeridianMission?.savedGlassMeridian?.laneRepair?
      .progress.first { $0.target == .outer }?.seconds ?? -1
    let evidence = "outer qualified=\(seconds) reason=\(snapshot.c01LaneRepairWorkRuntime.reason.prefix(128))"
    try #require(abs(seconds - NativeC01LaneRepair.qualifiedSeconds) < 1e-8,
      Comment(rawValue: evidence))
  }

  /// Explicit partial and failed-writer schedules retain their exact requested steps.
  func work(_ runtime: GameRuntime, intervals: Int) async {
    for _ in 0..<intervals { _ = await runtime.advance(delta: 0.05) }
  }
}

struct NativeC01LaneRepairUnitTests {
  @Test func exactQualificationAndActualPositiveTimeBounds() {
    #expect(NativeC01LaneRepair.qualifies(range: 50, speed: 1, aim: 2 * .pi / 180))
    for range in [49.999, 150.001, .nan, .infinity] {
      #expect(!NativeC01LaneRepair.qualifies(range: range, speed: 0, aim: 0))
    }
    #expect(!NativeC01LaneRepair.qualifies(range: 100, speed: 1.001, aim: 0))
    #expect(!NativeC01LaneRepair.qualifies(range: 100, speed: 0, aim: 0.035))
    #expect(NativeC01LaneRepair.credit(before: 0, start: 1, end: 1) == nil)
    #expect(NativeC01LaneRepair.credit(before: 0, start: 1, end: 2) == nil)
    #expect(abs((NativeC01LaneRepair.credit(before: 19.99, start: 1, end: 1.05) ?? 0) - 0.01) < 1e-8)
  }

  @Test func actualThreeTargetWorkInstallsSameStandardOnceAndRetainsRecorder() async throws {
    let f = try await C01LaneRepairJourneyFixture()
    defer { f.clean() }
    var game = try await f.atRelays()
    let source = try #require(game.glassMeridianMission?.savedGlassMeridian?.laneRepair?.source)
    #expect(source.anchors == game.commander.flightSimulation.anchors)
    let before = try #require(game.glassMeridianMission)
    let standard = try #require(before.savedGlassMeridian?.timingStandard?.capture)
    let cargo = try #require(game.commander.checkedCargoTonnes)
    let recorder = before.savedGlassMeridian?.surveyor
    for (index, target) in NativeC01LaneRepair.Target.allCases.enumerated() {
      let runtime = try await f.runtime(at: target, game: game)
      var armed = await runtime.snapshot()
      try #require(armed.c01LaneRepairEndpoint() != nil)
      await f.work(runtime)
      game = await runtime.snapshot()
      let leaf = try #require(game.glassMeridianMission?.savedGlassMeridian?.laneRepair)
      #expect(leaf.receipts.count == index + 1)
      #expect(Set(leaf.receipts.map(\.target)).count == index + 1)
      #expect(game.glassMeridianMission?.savedGlassMeridian?.timingStandard?.capture == standard)
      #expect(game.glassMeridianMission?.savedGlassMeridian?.surveyor == recorder)
      #expect(game.commander.checkedCargoTonnes == cargo - (index == 2 ? 1 : 0))
      #expect((leaf.installation != nil) == (index == 2))
      #expect(game.commander.valid)
    }
    let final = try #require(game.glassMeridianMission)
    #expect(final.milestones == [0, 1, 2, 3, 4, 5])
    #expect(final.outcome == .active && final.completionReceipt == nil)
    #expect(game.commander.credits == f.game.commander.credits)
    #expect(game.commander.scriptState.savedClueJournal == f.game.commander.scriptState.savedClueJournal)
    let runtime = GameRuntime(game: game, saveURL: f.save)
    _ = await runtime.advance(delta: 0.05)
    let published = await runtime.snapshot()
    let publishedMission = try #require(published.glassMeridianMission)
    let clinic = try #require(publishedMission.savedGlassMeridian?.clinicEscort)
    let opening = try #require(final.savedGlassMeridian)
    let installation = try #require(opening.laneRepair?.installation)
    let capture = try #require(opening.surveyor?.capture)
    try #require(opening.clinicEscort == nil)
    try #require(final.ownedEncounters[NativeC01ClinicEscort.sourceEncounter] == nil)
    try #require(game.commander.nativePeople?.clinicSource == nil)
    // Lane installation finishes after the clinic commit in its frame. The next
    // existing advance may register clinic stock, but cannot change prior work.
    try #require(published.c01ClinicSourceContext() == clinic.source)
    try #require(clinic.source.mission == final.id)
    try #require(clinic.source.owner == opening.permission.owner)
    try #require(clinic.source.permission == opening.permission.operation)
    try #require(clinic.source.installation == installation.operation)
    try #require(clinic.source.recorder == capture.operation)
    try #require(clinic.source.visit == published.commander.flightSimulation.visit)
    try #require(clinic.source.physicalTime == published.commander.flightSimulation.physicalTime)
    try #require(clinic.source.physicalTime > installation.physicalTime)
    try #require(clinic.birth.registration
      == NativeC01ClinicPeople.registrationOperation(owner: clinic.source.owner))
    try #require(clinic.birth.physicalTime == clinic.source.physicalTime)
    try #require(clinic.birth.reference == clinic.source.reference)
    try #require(clinic.birth.cradle
      == ShipPose(position: clinic.source.position, orientation: Basis3()))
    try #require(clinic.birth.units.count == 2)
    for ordinal in 0..<2 {
      let unit = try #require(clinic.birth.unit(ordinal))
      try #require(unit.registeredHull
        == NativeC01ClinicPeople.hull(owner: clinic.source.owner, ordinal: ordinal))
      try #require(unit.pilot
        == .clinicPilot(NativeC01ClinicPeople.person(owner: clinic.source.owner, ordinal: ordinal)))
    }
    try #require(clinic.parkedLosses.isEmpty && clinic.launches.isEmpty && clinic.arrival == nil)
    try #require(NativeC01ClinicEscortSave.valid(
      clinic, mission: publishedMission, commander: published.commander))
    let people = try #require(published.commander.nativePeople?.clinicSource)
    try #require(people.registration.source == clinic.source)
    try #require(people.registration.birth == clinic.birth)
    try #require(people.assignments.isEmpty && people.dispositions.isEmpty)
    try #require(NativeC01ClinicPeopleSave.sourceClaimsMatch(
      clinic, mission: publishedMission, commander: published.commander))
    let cohort = try #require(
      publishedMission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter])
    try #require(cohort.admitted && cohort.valid)
    let aliases = [NativeC01ClinicEscort.cradleTarget,
      NativeC01ClinicEscort.stockTarget(0), NativeC01ClinicEscort.stockTarget(1)]
    try #require(Set(cohort.actors.keys) == Set(aliases))
    for alias in aliases {
      let actor = try #require(cohort.actors[alias])
      let ordinal = NativeC01ClinicEscort.stockOrdinal(alias: alias)
      try #require(NativeC01ClinicEscort.original(actor, source: clinic.source, ordinal: ordinal))
      try #require(actor.presence == .present)
      let body = try #require(published.bodies.first { $0.missionActorID == actor.identity })
      try #require(body.id == actor.body.id && body.missionInstanceID == final.id)
      let physical = try #require(actor.body.physical)
      try #require(body.physical?.identity == physical.identity)
      try #require(physical.identity.visit == clinic.source.visit)
      try #require(physical.deathIncidentID == nil && physical.deathOrigin == nil)
      try #require(NativeC01ClinicEscort.nativeValid(physical, cradle: ordinal == nil))
      let berth = ordinal.map {
        NativeC01ClinicEscort.parkedPose(cradle: clinic.birth.cradle, ordinal: $0)
      } ?? clinic.birth.cradle
      try #require(actor.body.position == clinic.birth.reference.shipPoint(berth.position))
      try #require(actor.body.orientation
        == berth.orientation.relative(to: clinic.birth.reference.orientation))
      try #require(actor.body.energy == actor.body.scriptNPC?.fit.definition.energy)
      let resources = try #require(physical.npc?.resources)
      try #require(resources.frontShield == resources.frontCapacity)
      try #require(resources.rearShield == resources.rearCapacity)
    }
    try #require(published.commander.valid)
    var expected = final
    expected.savedGlassMeridian?.clinicEscort = clinic
    expected.ownedEncounters[NativeC01ClinicEscort.sourceEncounter] = cohort
    expected.revision = final.revision + 1
    #expect(publishedMission == expected)
    #expect(published.commander.checkedCargoTonnes == cargo - 1)
    #expect(published.commander.credits == game.commander.credits)
    #expect(published.commander.scriptState.savedClueJournal == game.commander.scriptState.savedClueJournal)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: f.save)
    let loaded = await cold.snapshot()
    #expect(loaded.glassMeridianMission == publishedMission)
    #expect(loaded.glassMeridianMission?.savedGlassMeridian == publishedMission.savedGlassMeridian)
    #expect(loaded.glassMeridianMission?.savedGlassMeridian?.laneRepair == opening.laneRepair)
    #expect(loaded.glassMeridianMission?.savedGlassMeridian?.timingStandard == opening.timingStandard)
    #expect(loaded.glassMeridianMission?.savedGlassMeridian?.surveyor == recorder)
    #expect(loaded.commander.nativePeople?.clinicSource == people)
    #expect(loaded.commander.valid)
    #expect(loaded.c01LaneRepairWorkRuntime.arm == nil)
    #expect(loaded.commander.checkedCargoTonnes == game.commander.checkedCargoTonnes)
    #expect(loaded.commander.credits == game.commander.credits)
    #expect(loaded.commander.scriptState.savedClueJournal == game.commander.scriptState.savedClueJournal)
  }

  @Test func actualPartialSaveReloadRequiresFreshExplicitArmingAndEscapeStopsCredit() async throws {
    let f = try await C01LaneRepairJourneyFixture()
    defer { f.clean() }
    let runtime = try await f.runtime(at: .inner, game: try await f.atRelays())
    await f.work(runtime, intervals: 40)
    let partial = await runtime.snapshot()
    try #require(partial.c01LaneRepairQualifiedSeconds > 1.9)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: f.save)
    let loaded = await cold.snapshot()
    #expect(loaded.c01LaneRepairWorkRuntime.arm == nil)
    let seconds = loaded.c01LaneRepairQualifiedSeconds
    _ = await cold.advance(delta: 0.05)
    #expect(await cold.snapshot().c01LaneRepairQualifiedSeconds == seconds)
    await runtime.key("escape")
    let stopped = await runtime.snapshot()
    #expect(stopped.c01LaneRepairWorkRuntime.arm == nil)
    await f.work(runtime, intervals: 20)
    #expect(await runtime.snapshot().c01LaneRepairQualifiedSeconds == stopped.c01LaneRepairQualifiedSeconds)
    #expect(await runtime.snapshot().glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.isEmpty == true)
  }

  @Test func actualSelectedContactRejectsChangedTargetEpochUnsafeRangeAndMovingCarrier() async throws {
    let f = try await C01LaneRepairJourneyFixture()
    defer { f.clean() }
    let runtime = try await f.runtime(at: .inner, game: try await f.atRelays())
    var armed = await runtime.snapshot()
    try #require(armed.c01LaneRepairEndpoint() != nil)
    var changed = armed
    changed.weaponsTargetID = nil
    #expect(changed.c01LaneRepairEndpoint() == nil)
    changed = armed
    changed.nativeStationRuntimeEpoch = UUID()
    #expect(changed.c01LaneRepairEndpoint() == nil)
    changed = armed
    changed.speed = 2
    #expect(changed.c01LaneRepairEndpoint() == nil)
    changed = armed
    var pose = changed.commander.flightSimulation.pose
    pose.position = pose.position + pose.orientation.z * 70
    NativeStationTestFixture.reframe(&changed, to: pose)
    #expect(changed.c01LaneRepairEndpoint() == nil)
    #expect(changed.glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.isEmpty == true)
    #expect(changed.glassMeridianMission?.savedGlassMeridian?.timingStandard?.held == true)
  }

  @Test func actualThirdReceiptFailedWriterRetainsCargoUntilFreshQualifiedRetry() async throws {
    let f = try await C01LaneRepairJourneyFixture()
    defer { f.clean() }
    var game = try await f.atRelays()
    for target in [NativeC01LaneRepair.Target.inner, .middle] {
      let runtime = try await f.runtime(at: target, game: game)
      await f.work(runtime)
      game = await runtime.snapshot()
      try #require(game.glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.count
        == (target == .inner ? 1 : 2))
    }
    let runtime = try await f.runtime(at: .outer, game: game)
    await f.work(runtime, intervals: 399)
    let cargo = game.commander.checkedCargoTonnes
    let pointer = try Data(contentsOf: f.save)
    try FileManager.default.removeItem(at: f.save)
    try FileManager.default.createDirectory(at: f.save, withIntermediateDirectories: false)
    try await f.completeOuterWorkWithWriterBlocked(runtime)
    let refused = await runtime.snapshot()
    #expect(refused.glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.count == 2)
    #expect(refused.glassMeridianMission?.savedGlassMeridian?.laneRepair?.installation == nil)
    #expect(refused.glassMeridianMission?.savedGlassMeridian?.timingStandard?.held == true)
    #expect(refused.commander.checkedCargoTonnes == cargo)
    #expect(refused.glassMeridianMission?.milestones == [0, 1, 2, 3, 4])
    try FileManager.default.removeItem(at: f.save)
    try pointer.write(to: f.save, options: .atomic)
    await f.work(runtime)
    let committed = await runtime.snapshot()
    #expect(committed.glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.count == 3)
    #expect(committed.glassMeridianMission?.savedGlassMeridian?.timingStandard?.used != nil)
    #expect(committed.commander.checkedCargoTonnes == cargo.map { $0 - 1 })
  }
  @Test(arguments: [false, true])
  func completedPendingThirdReceiptNeedsFreshFrameAfterEscapeOrColdReload(_ coldReload: Bool) async throws {
    let f = try await C01LaneRepairJourneyFixture()
    defer { f.clean() }
    var game = try await f.atRelays()
    for target in [NativeC01LaneRepair.Target.inner, .middle] {
      let prior = try await f.runtime(at: target, game: game)
      await f.work(prior)
      game = await prior.snapshot()
      try #require(game.glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.count
        == (target == .inner ? 1 : 2))
    }
    let runtime = try await f.runtime(at: .outer, game: game)
    await f.work(runtime, intervals: 399)
    let beforeFailure = await runtime.snapshot()
    let standard = try #require(beforeFailure.glassMeridianMission?.savedGlassMeridian?.timingStandard)
    let recorder = beforeFailure.glassMeridianMission?.savedGlassMeridian?.surveyor
    let cargo = try #require(beforeFailure.commander.checkedCargoTonnes)
    let pointer = try Data(contentsOf: f.save)
    try FileManager.default.removeItem(at: f.save)
    try FileManager.default.createDirectory(at: f.save, withIntermediateDirectories: false)
    try await f.completeOuterWorkWithWriterBlocked(runtime)
    let pending = await runtime.snapshot()
    let pendingLeaf = try #require(pending.glassMeridianMission?.savedGlassMeridian?.laneRepair)
    let measured = try #require(pendingLeaf.progress.first { $0.target == .outer })
    try #require(abs(measured.seconds - 20) < 1e-8 && pendingLeaf.receipts.count == 2)
    #expect(pendingLeaf.installation == nil)
    #expect(pending.commander.checkedCargoTonnes == cargo)
    try FileManager.default.removeItem(at: f.save)
    try pointer.write(to: f.save, options: .atomic)

    let resumed: GameRuntime
    if coldReload {
      // Save the actual current pending20s. Loading this history must not restore live arming.
      try await runtime.save(to: f.save)
      resumed = GameRuntime(game: Game(executive: false))
      try await resumed.load(from: f.save)
    } else {
      await runtime.key("escape")
      resumed = runtime
    }
    var restored = await resumed.snapshot()
    #expect(restored.c01LaneRepairWorkRuntime.arm == nil)
    let restoredLeaf = try #require(restored.glassMeridianMission?.savedGlassMeridian?.laneRepair)
    #expect(restoredLeaf.progress.first { $0.target == .outer }?.segments == measured.segments)
    #expect(restoredLeaf.receipts.count == 2 && restoredLeaf.installation == nil)
    _ = await resumed.advance(delta: 0.05)
    #expect(await resumed.snapshot().glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.count == 2)
    // Cold restoration may clear the UI target; select the exact current physical actor again.
    restored = await resumed.snapshot()
    let source = try #require(restored.glassMeridianMission?.savedGlassMeridian?.laneRepair?.source)
    let actor = try #require(restored.c01LaneRepairActor(source: source, target: .outer))
    try await resumed.scriptCommand { current in current.weaponsTargetID = actor.body.id }
    await resumed.key("return")
    try #require(await resumed.snapshot().c01LaneRepairWorkRuntime.review != nil)
    await resumed.key("return")
    let armed = await resumed.snapshot()
    let live = try #require(armed.c01LaneRepairWorkRuntime.arm?.binding)
    let armedProgress = try #require(armed.glassMeridianMission?.savedGlassMeridian?.laneRepair?
      .progress.first { $0.target == .outer })
    #expect(armedProgress.segments == measured.segments)
    #expect(armedProgress.completionArm == live)
    #expect(armedProgress.seconds == measured.seconds)
    #expect(armed.glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.count == 2)
    #expect(armed.glassMeridianMission?.savedGlassMeridian?.timingStandard == standard)
    let freshStart = armed.commander.flightSimulation.physicalTime
    await f.work(resumed)
    let committed = await resumed.snapshot()
    let final = try #require(committed.glassMeridianMission?.savedGlassMeridian?.laneRepair)
    let receipt = try #require(final.receipts.first { $0.target == .outer })
    #expect(final.receipts.count == 3 && final.installation != nil)
    #expect(receipt.confirmation.arm == live)
    #expect(receipt.confirmation.start >= freshStart)
    #expect(receipt.confirmation.end > receipt.confirmation.start)
    #expect(receipt.confirmation.end - receipt.confirmation.start <= NativeC01LaneRepair.maximumPhysicalInterval)
    #expect(final.progress.first { $0.target == .outer }?.segments == measured.segments)
    #expect(committed.commander.checkedCargoTonnes == cargo - 1)
    #expect(committed.glassMeridianMission?.savedGlassMeridian?.timingStandard?.capture == standard.capture)
    #expect(committed.glassMeridianMission?.savedGlassMeridian?.timingStandard?.used == final.installation)
    #expect(committed.glassMeridianMission?.savedGlassMeridian?.surveyor == recorder)
    #expect(committed.glassMeridianMission?.milestones == [0, 1, 2, 3, 4, 5])
    #expect(committed.commander.valid)
    _ = await resumed.advance(delta: 0.05)
    let replay = await resumed.snapshot()
    #expect(replay.glassMeridianMission?.savedGlassMeridian?.laneRepair == final)
    #expect(replay.commander.checkedCargoTonnes == cargo - 1)
    let reloaded = GameRuntime(game: Game(executive: false))
    try await reloaded.load(from: f.save)
    #expect(await reloaded.snapshot().glassMeridianMission?.savedGlassMeridian?.laneRepair == final)
    #expect(await reloaded.snapshot().c01LaneRepairWorkRuntime.arm == nil)
  }

  @Test func crossingNativeOccluderRefusesWholeIntervalDespiteBothClearEndpointRays() async throws {
    let f = try await C01LaneRepairJourneyFixture()
    defer { f.clean() }
    let runtime = try await f.runtime(at: .inner, game: try await f.atRelays())
    let armed = await runtime.snapshot()
    // Controlled placement keeps the selected actual native face150m ahead.
    var proposed = armed.commander.flightSimulation.pose
    proposed.position = proposed.position - proposed.orientation.z * 50
    let pose = proposed
    let source = try #require(armed.glassMeridianMission?.savedGlassMeridian?.laneRepair?.source)
    let occluder = try #require(armed.c01LaneRepairActor(source: source, target: .middle))
    let index = try #require(armed.bodies.firstIndex { $0.id == occluder.body.id })
    // Retain the runtime that actually armed this work. A new runtime rotates its native
    // epoch and cannot carry this one live arm into a later interval.
    await runtime.nativeCommand { game in
      NativeStationTestFixture.reframe(&game, to: pose)
      // Same actual closed relay mesh. Its x extent is+-7.56m; both x+-9 endpoints
      // miss the ray while its attained18m transverse movement crosses the whole interval.
      game.bodies[index].position = .init(-9, 0, 110)
      game.bodies[index].orientation = Basis3()
      game.bodies[index].rotation = 0
      game.bodies[index].physical?.angularVelocity = .init(0, 0, 0)
      game.bodies[index].physical?.velocity = pose.orientation.apply(.init(360, 0, 0))
      game.persistScriptActors()
    }
    var game = await runtime.snapshot()
    try #require(game.nativeStationRuntimeEpoch == armed.nativeStationRuntimeEpoch)
    try #require(game.c01LaneRepairWorkRuntime.arm?.binding.epoch == game.nativeStationRuntimeEpoch)
    // Passive native inertia owns the motion; the speed-zero powered NPC view remains valid.
    try #require(game.bodies[index].scriptNPC?.velocity.length == 0)
    try #require(game.bodies[index].scriptNPC?.valid == true)
    try #require(game.c01LaneRepairEndpoint() != nil)
    let prior = game.c01LaneRepairQualifiedSeconds
    try await runtime.save(to: f.save)
    _ = await runtime.advance(delta: 0.05)
    var after = await runtime.snapshot()
    // The exact endpoint native ray is clear again; it cannot justify the occluded interval.
    try #require(after.c01LaneRepairEndpoint() != nil)
    let moved = try #require(after.bodies.first { $0.missionActorID == occluder.identity })
    #expect(abs(moved.position.x - 9) < 1e-5)
    #expect(after.c01LaneRepairQualifiedSeconds == prior)
    #expect(after.glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.isEmpty == true)
    // The same real native obstacle now moves away from a fully clear interval.
    _ = await runtime.advance(delta: 0.05)
    let clear = await runtime.snapshot()
    #expect(clear.c01LaneRepairQualifiedSeconds > prior,
      "Later interval result: \(clear.c01LaneRepairWorkRuntime.lastIntervalResult?.rawValue ?? "not-recorded")")
    #expect(clear.glassMeridianMission?.savedGlassMeridian?.timingStandard?.held == true)
  }

  @Test func rotatingSelectedNativeFaceConservativelyRefusesContinuousWork() async throws {
    let f = try await C01LaneRepairJourneyFixture()
    defer { f.clean() }
    let armed = try await f.runtime(at: .inner, game: try await f.atRelays())
    var game = await armed.snapshot()
    let source = try #require(game.glassMeridianMission?.savedGlassMeridian?.laneRepair?.source)
    let target = try #require(game.c01LaneRepairActor(source: source, target: .inner))
    let index = try #require(game.bodies.firstIndex { $0.id == target.body.id })
    game.bodies[index].physical?.angularVelocity = .init(0, 0.01, 0)
    game.persistScriptActors()
    try #require(game.c01LaneRepairEndpoint() != nil)
    let prior = game.c01LaneRepairQualifiedSeconds
    let runtime = GameRuntime(game: game, saveURL: f.save)
    try await runtime.save(to: f.save)
    _ = await runtime.advance(delta: 0.05)
    let after = await runtime.snapshot()
    #expect(after.c01LaneRepairQualifiedSeconds == prior)
    #expect(after.glassMeridianMission?.savedGlassMeridian?.laneRepair?.receipts.isEmpty == true)
  }

}


extension NativeC01LaneRepairUnitTests {
  @Test
  func actualArmedLaneAdvanceRetainsCompleteTimingHistoryAndRejectsForeignRevision() async throws {
    // Reuse the maintained controlled earlier history and actual pickup/arming.
    // This is a regression for the matched executor chain, not an M01 route claim.
    let fixture = try await C01LaneRepairJourneyFixture()
    defer { fixture.clean() }
    let game = try await fixture.atRelays()
    let runtime = try await fixture.runtime(at: .inner, game: game)
    let before = await runtime.snapshot()
    let mission = try #require(before.glassMeridianMission)
    let opening = try #require(mission.savedGlassMeridian)
    let timing = try #require(opening.timingStandard)
    let lane = try #require(opening.laneRepair)
    let capture = try #require(timing.capture)
    let binding = try #require(before.c01LaneRepairWorkRuntime.arm?.binding)
    let beforeTime = before.commander.flightSimulation.physicalTime
    let timingValid = NativeC01TimingStandardSave.valid(
      timing, mission: mission, commander: before.commander)
    let laneHistory = NativeC01LaneRepairSave.historyJoins(
      lane, mission: mission, commander: before.commander)
    try #require(timingValid && laneHistory)
    try #require(timing.held && lane.installation == nil && binding.target == .inner)
    var foreign = mission
    foreign.revision = 0
    let foreignTiming = NativeC01TimingStandardSave.valid(
      timing, mission: foreign, commander: before.commander)
    let foreignLane = NativeC01LaneRepairSave.historyJoins(
      lane, mission: foreign, commander: before.commander)
    #expect(!foreignTiming && !foreignLane)
    // Keep the actual fixture.work -> actor.advance -> finishPreparedFrame ->
    // lane endpoint -> complete timing/actor validation chain from crash 22962.
    await fixture.work(runtime, intervals: 3)
    let after = await runtime.snapshot()
    let afterMission = try #require(after.glassMeridianMission)
    let afterOpening = try #require(afterMission.savedGlassMeridian)
    let afterTiming = try #require(afterOpening.timingStandard)
    let afterLane = try #require(afterOpening.laneRepair)
    let afterCapture = try #require(afterTiming.capture)
    #expect(abs(after.commander.flightSimulation.physicalTime - beforeTime - 0.15) < 1e-9)
    #expect(afterTiming.source == timing.source && afterCapture == capture)
    #expect(afterTiming.held && afterLane.installation == nil)
    #expect(after.c01LaneRepairWorkRuntime.arm?.binding == binding)
    let completeTiming = NativeC01TimingStandardSave.valid(
      afterTiming, mission: afterMission, commander: after.commander)
    let completeLane = NativeC01LaneRepairSave.historyJoins(
      afterLane, mission: afterMission, commander: after.commander)
    #expect(completeTiming && completeLane)
    let oldSeconds = lane.progress.first { $0.target == .inner }?.seconds ?? 0
    let newSeconds = afterLane.progress.first { $0.target == .inner }?.seconds ?? 0
    #expect(newSeconds >= oldSeconds)
    let encoded = try JSONEncoder().encode(afterTiming)
    let roundTrip = try NativeC01TimingStandardSave.decodeClosed(encoded)
    #expect(roundTrip == afterTiming)
  }
}
