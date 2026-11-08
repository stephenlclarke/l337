import Foundation
import Testing

@testable import L337Core

struct CurrentNewtEmptyCellCustodyTests {
  @Test(arguments: ["stowed", "moving", "moving-writer"])
  func actualSelectedPersonCaptureKeepsEmptyGeometryThroughCoastRemovalAndColdLoad(stage: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await captureSelectedPerson(storage: storage, stage: stage)
    var game = await runtime.snapshot()
    let record = try #require(game.commander.savedEMPState?.records.values.first)
    #expect(record.crewTotal == 1 && record.crewAboard == 0 && !record.isRecovered)
    let parent = try #require(record.hull.binding)
    let bodyCandidate = game.bodies.first { $0.physical?.identity == parent }
    let body = try #require(bodyCandidate)
    let stock = try #require(body.physical?.currentNewtKitStock)
    let source = try #require(CurrentNewtKitSource.current)
    let ownedPreparationRequired1 = game.currentNewtCellComponentContract(for: body)
    let cell = try #require(ownedPreparationRequired1)
    #expect(!cell.occupied && cell.kitID == stock.issue.kitID)
    let allSatisfied = cell.parts.count == 5 && cell.parts.allSatisfy { $0.id != "actual-identified-person" }
    #expect(allSatisfied)
    #expect(CurrentNewtEmptyCellPhysicalSource.cellWithoutSelectedPerson.matches(
      massKilograms: cell.mass.massKilograms, centreMetres: cell.mass.centreOfMassMetres,
      inertiaAboutCentreOfMassKgM2: cell.mass.inertiaKgM2))
    let ownedPreparationRequired2 = try game.currentNewtGeometryComponents(for: body)
    let parts = try #require(ownedPreparationRequired2)
    let allSatisfied2 = parts.allSatisfy { $0.id != "actual-identified-person" }
    #expect(allSatisfied2)
    let dryCandidate = parts.first { $0.id == "unchanged-current-newt-dry" }
    let dry = try #require(dryCandidate)
    let emptyDisplay = try #require(CurrentNewtEmptyCellDisplaySource.emptyDisplayMesh)
    let capsule = try #require(OriginalCryostasisCapsule.source)
    #expect(dry.collisionMesh?.vertices == capsule.collisionDesign.rawMesh.vertices)
    #expect(dry.collisionMesh?.faces == capsule.collisionDesign.rawMesh.faces)
    #expect(dry.displayMesh?.vertices == emptyDisplay.vertices)
    #expect(dry.displayMesh?.faces == emptyDisplay.faces)
    #expect(dry.displayMesh?.materials == emptyDisplay.materials)
    #expect(dry.displayMesh?.faceMaterials == emptyDisplay.faceMaterials)
    #expect(dry.displayMesh?.opticalEnclosure?.paneFace == emptyDisplay.opticalEnclosure?.paneFace)
    #expect(dry.displayMesh?.opticalEnclosure?.firstInteriorFace
      == emptyDisplay.opticalEnclosure?.firstInteriorFace)
    let obstaclesCandidate = game.currentNewtRigidWorkObstacles(for: body)
    let obstacles = try #require(obstaclesCandidate)
    #expect(obstacles.count == parts.filter { $0.collisionMesh != nil }.count)
    let ownedPreparationRequired3 = game.currentNewtKitLoad(for: body)
    let load = try #require(ownedPreparationRequired3)
    #expect(load.people.isEmpty)
    let mass = try #require(source.loadedMechanicalMass(stock: stock, load: load, cell: cell))
    let model = game.modelPose(of: body)
    let expected = try #require(CurrentNewtKitMass.combined(parts.map { part in
      CurrentNewtKitMass.translated(part.massProperties,
        by: model.shipPoint(part.pose.position))
    }))
    #expect(source.matchesMass(mass, expected))
    if stage == "stowed" {
      let extra = try #require(source.loadModel?.masses(load))
      let reference = CurrentNewtEmptyCellPhysicalSource.installedStowedWithoutSelectedPerson
      let configured = try #require(CurrentNewtKitMass.combined([
        .init(massKilograms: reference.massKilograms, centreOfMassMetres: reference.centreMetres,
          inertiaKgM2: reference.inertiaAboutCentreOfMassKgM2),
      ] + extra))
      #expect(source.matchesMass(mass, configured))
    } else {
      try #require(stock.phase == .actuating && stock.interruptedAt != nil)
      #expect(stock.work.loweredFraction > 0 && stock.work.loweredFraction < 1)
      #expect(stock.work.guideWorkJoules > 0 && stock.work.ejectionWorkJoules == 0)
    }
    let start = game.commander.flightSimulation.physicalTime
    let ownedPreparationRequired4 = game.currentNewtMechanicalPlan(.init(start: start, end: start + 0.1))
    let plan = try #require(ownedPreparationRequired4)
    let coastCandidate = plan.coasts.first { $0.actor == parent }
    let coast = try #require(coastCandidate)
    #expect(source.matchesMass(coast.mass, mass) && coast.internalBrakeAt == nil)
    _ = await runtime.advance(delta: 0.1)
    game = await runtime.snapshot()
    #expect(game.commander.flightSimulation.physicalTime == start + 0.1)
    let movingCandidate = game.bodies.first { $0.physical?.identity == parent }
    let moving = try #require(movingCandidate)
    #expect(game.currentNewtCellComponentContract(for: moving)?.occupied == false)
    let world = game.modelPose(of: moving)
    NativePagedSalvageFixture.moveObserver(&game, to: .init(
      position: world.position + .init(50000, 0, 0), orientation: game.commander.flightSimulation.pose.orientation))
    try #require(game.bodies.first { $0.physical?.identity == parent }?.leavesLocalBubble == true)
    let departing = GameRuntime(game: game, saveURL: storage.url)
    try await departing.save(to: storage.url)
    _ = await departing.advance(delta: 0.1)
    let parked = await departing.snapshot()
    #expect(!parked.bodies.contains { $0.physical?.identity == parent })
    let archive = try #require(parked.commander.savedEMPState?.records[record.source])
    #expect(archive.hull.binding == nil && archive.hull.body.physical?.currentNewtKitStock?.issue == stock.issue)
    #expect(parked.currentNewtCellComponentContract(for: archive.hull.body)?.occupied == false)
    try await departing.save(to: storage.url)
    let cold = GameRuntime()
    try await cold.load(from: storage.url, persistMigrations: false)
    let loaded = await cold.snapshot()
    let retained = try #require(loaded.commander.savedEMPState?.records[record.source])
    #expect(retained.crewCaptures == archive.crewCaptures && retained.pods.isEmpty)
    #expect(retained.hull.body.physical?.currentNewtKitStock?.issue == stock.issue)
    #expect(loaded.commander.nativePeople == parked.commander.nativePeople)
    #expect(loaded.currentNewtCellComponentContract(for: retained.hull.body)?.occupied == false)
    #expect(loaded.commander.valid)
  }

  @Test(arguments: ["unknown", "foreign-capture"])
  func missingOrForeignCustodyCannotSelectAnEmptyOrResurrectedCell(fault: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await captureSelectedPerson(storage: storage)
    let actual = await runtime.snapshot()
    let original = try #require(actual.commander.savedEMPState?.records.values.first)
    let parent = try #require(original.hull.binding)
    let bodyCandidate2 = actual.bodies.first { $0.physical?.identity == parent }
    let body = try #require(bodyCandidate2)
    let ownedPreparationRequired5 = actual.currentNewtCellComponentContract(for: body)?.occupied == false
    try #require(ownedPreparationRequired5)
    var changed = actual
    var record = original
    if fault == "unknown" {
      record.crewCaptures = []
    } else {
      let capture = try #require(record.crewCaptures.first)
      let foreign = try #require(changed.commander.flightSimulation.player)
      record.crewCaptures = [.init(operation: capture.operation, ordinals: capture.ordinals,
        episode: capture.episode, actor: foreign, collector: capture.collector,
        owner: capture.owner, hull: capture.hull, tool: capture.tool, physicalTime: capture.physicalTime)]
    }
    changed.commander.savedEMPState?.records[record.source] = record
    let before = changed
    #expect(changed.currentNewtCellComponentContract(for: body) == nil)
    #expect(throws: (any Error).self) { _ = try changed.currentNewtGeometryComponents(for: body) }
    #expect(changed.commander == before.commander && changed.bodies == before.bodies)
    #expect(actual.commander.savedEMPState?.records[record.source] == original)
    #expect(actual.currentNewtCellComponentContract(for: body)?.occupied == false)
  }

  @Test
  func actualHullDeathRetainsTheOriginalPersonMassAndOccupiedDisplay() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try #require(try releaseDamagedEMPBoundary(&game, seed: nil))
    let bodyCandidate3 = game.bodies.first { $0.physical?.empSource != nil }
    let body = try #require(bodyCandidate3)
    let logical = try #require(body.physical?.empSource)
    let issue = try #require(body.physical?.currentNewtKitStock?.issue)
    let player = try #require(game.commander.flightSimulation.player)
    let originCandidate = game.makeAttackOrigin(owner: player)
    let origin = try #require(originCandidate)
    _ = game.applyCombatHit(.init(target: .body(body.id), distance: body.position.length,
      point: body.position), origin: origin, kind: .laser, damage: 10000)
    game.resolveDestroyed()
    let dead = try #require(game.commander.savedEMPState?.records[logical])
    try #require(dead.terminal && dead.crewOutcome(ordinal: issue.person.ordinal) == .deceasedWithHull)
    let ownedPreparationRequired6 = game.currentNewtKitLoad(for: dead.hull.body)
    let load = try #require(ownedPreparationRequired6)
    let containsMatch = load.people.contains { $0.identity == issue.person && $0.profile == issue.personProfile }
    #expect(containsMatch)
    let ownedPreparationRequired7 = game.currentNewtCellComponentContract(for: dead.hull.body)
    let cell = try #require(ownedPreparationRequired7)
    let source = try #require(CurrentNewtKitSource.current)
    #expect(cell.occupied && source.matchesMass(cell.mass, source.podMass))
    let containsMatch2 = cell.parts.contains { $0.id == "actual-identified-person" && $0.mass.massKilograms == 100 }
    #expect(containsMatch2)
    let dryCandidate2 = cell.parts.first { $0.id == "unchanged-current-newt-dry" }
    let dry = try #require(dryCandidate2)
    let display = try #require(OriginalCryostasisCapsule.source?.displayMesh)
    #expect(dry.displayMesh?.vertices == display.vertices && dry.displayMesh?.faces == display.faces)
    #expect(dry.displayMesh?.materials == display.materials)
    #expect(dead.crewCaptures.isEmpty && dead.pods.isEmpty)
  }

  @Test
  func longAcceptedGapPreservesTheActualNativeParkAndObservesPortableService() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await parkedRuntime(storage: storage)
    _ = await runtime.advance(delta: 0.1)
    _ = await runtime.advance(delta: 0.1)
    var game = await runtime.snapshot()
    let original = try #require(game.commander.savedEMPState?.records.values.first)
    let stock = try #require(original.hull.body.physical?.currentNewtKitStock)
    let receipt = try #require(stock.receipt)
    let native = try #require(game.commander.alienStorageState?.current.salvage.native.wrecks[original.wreck])
    let time = game.commander.flightSimulation.physicalTime
    try #require(time - original.hull.physicalTime > 0.1)
    let captureObserved = game.observeCurrentNewtArchiveForCapture(receipt, at: time)
    try #require(captureObserved)
    let observed = try #require(game.commander.savedEMPState?.records[original.source])
    let after = try #require(observed.hull.body.physical?.currentNewtKitStock)
    #expect(observed.hull.body.position == original.hull.body.position)
    #expect(observed.hull.body.orientation == original.hull.body.orientation)
    #expect(observed.hull.body.physical?.velocity == original.hull.body.physical?.velocity)
    #expect(observed.hull.body.physical?.angularVelocity == original.hull.body.physical?.angularVelocity)
    #expect(observed.hull.binding == nil && observed.hull.physicalTime == time)
    #expect(game.commander.alienStorageState?.current.salvage.native.wrecks[original.wreck] == native)
    #expect(after.issue == stock.issue && after.work == stock.work && after.receipt == receipt)
    #expect(after.observedAt == time && after.serviceCapturedAt == nil)
    let source = try #require(CurrentNewtKitSource.current)
    #expect(source.matchesCharges(after.charges, source.charges(at: time,
      actuation: receipt.actuation, work: stock.work)))
    #expect(game.commander.valid)
  }

  @Test
  func fullGapProjectionAndNonprincipalExhaustionCannotPartiallyPublishAnArchive() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await parkedRuntime(storage: storage)
    _ = await runtime.advance(delta: 0.1)
    _ = await runtime.advance(delta: 0.1)
    let game = await runtime.snapshot()
    let record = try #require(game.commander.savedEMPState?.records.values.first)
    let ownedPreparationRequired8 = game.currentNewtArchiveCoastProjection(for: record.hull)
    let projection = try #require(ownedPreparationRequired8)
    let time = game.commander.flightSimulation.physicalTime
    let duration = time - record.hull.physicalTime
    try #require(duration > 0.1)
    // The production native park stays authoritative. This immutable projection
    // tests the ordinary coast math without publishing a different parked pose.
    let result = try #require(projection.projected(at: time))
    let initial = try archivedState(record.hull)
    let end = try archivedState(result)
    let mass = projection.mass
    let velocity = CurrentNewtKitMass.centreVelocity(mass, state: initial)
    #expect((CurrentNewtKitMass.centre(mass, state: end)
      - CurrentNewtKitMass.centre(mass, state: initial) - velocity * duration).length < 1e-7)
    #expect((CurrentNewtKitMass.centreVelocity(mass, state: end) - velocity).length < 1e-8)
    let spin = CurrentNewtKitMass.spin(mass, state: initial)
    #expect((CurrentNewtKitMass.spin(mass, state: end) - spin).length < 1e-7)
    #expect(abs(CurrentNewtKitMass.kineticEnergy(mass, state: end)
      - CurrentNewtKitMass.kineticEnergy(mass, state: initial))
      <= max(1e-6, 1024 * Double.ulpOfOne * CurrentNewtKitMass.kineticEnergy(mass, state: initial)))
    #expect(result.physicalTime == time)
    let stock = try #require(result.body.physical?.currentNewtKitStock)
    #expect(stock.observedAt == time)
    try #require(initial.angularVelocity.cross(spin).length > 0)
    let source = try #require(CurrentNewtKitSource.current)
    let hugeDuration = 1_000_000.0
    let finite = try #require(CurrentNewtRigidCoast(initial: initial, mass: mass,
      duration: hugeDuration, maximumAngularSpeed: source.maximumAngularSpeed))
    try #require(finite.state(at: duration) != nil)
    // Nonprincipal integration has at most 65536 stages, each <= 0.1s. This
    // requested pure calculation cannot finish within that existing budget.
    #expect(finite.state(at: hugeDuration) == nil)
    #expect(projection.projected(at: record.hull.physicalTime + hugeDuration) == nil)
    #expect(projection.opening == record.hull)
    #expect(game.commander.savedEMPState?.records[record.source] == record)
    var failed = record.hull
    #expect(!game.coastCurrentNewtArchiveObject(&failed, to: time.nextUp))
    #expect(failed == record.hull)
    #expect(game.commander.flightSimulation.physicalTime == time)
  }

  private func parkedRuntime(storage: NativeStationTestStorage) async throws -> GameRuntime {
    var (game, source) = try NativePagedSalvageFixture.empGame()
    let record = try #require(game.commander.savedEMPState?.records[source.actor])
    let actor = try #require(record.hull.binding)
    let bodyCandidate4 = game.bodies.first { $0.physical?.identity == actor }
    let body = try #require(bodyCandidate4)
    let native = try #require(game.commander.alienStorageState?.current.salvage.native.wrecks[record.wreck])
    try #require(native.binding == actor)
    let model = game.modelPose(of: body)
    NativePagedSalvageFixture.moveObserver(&game, to: .init(position: model.position + .init(50000, 0, 0),
      orientation: game.commander.flightSimulation.pose.orientation))
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    _ = await runtime.advance(delta: 0.1)
    let parked = await runtime.snapshot()
    try #require(parked.commander.savedEMPState?.records[source.actor]?.hull.binding == nil)
    try #require(!parked.bodies.contains { $0.physical?.identity == actor })
    return runtime
  }

  private func archivedState(_ object: EMPStoredObject) throws -> CurrentNewtKitReceipt.BodyState {
    let physical = try #require(object.body.physical)
    return .init(pose: Game.modelPose(of: object.body, player: .init()),
      velocity: physical.velocity, angularVelocity: physical.angularVelocity)
  }

  private func captureSelectedPerson(storage: NativeStationTestStorage, stage: String = "stowed")
    async throws -> GameRuntime {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try #require(try releaseDamagedEMPBoundary(&game, seed: nil))
    let bodyCandidate5 = game.bodies.first { $0.physical?.empSource != nil }
    let body = try #require(bodyCandidate5)
    let physical = try #require(body.physical)
    let stock = try #require(physical.currentNewtKitStock)
    try #require(stock.phase == .stowed && stock.issue.person.ordinal == 0)
    if stage != "stowed" {
      let source = try #require(CurrentNewtKitSource.current)
      let logical = try #require(physical.empSource)
      let record = try #require(game.commander.savedEMPState?.records[logical])
      let episode = try #require(record.disableEpisodes.last)
      let sampledCandidate = episode.ejections.first { $0.ordinal == stock.issue.person.ordinal }
      let sampled = try #require(sampledCandidate)
      let due = episode.incident.physicalTime + sampled.delay
      try #require(due + source.dropDuration < episode.deadline)
      let frontier = due + source.dropDuration * 0.5
      try withEMPUnitWriter(&game) { game, publish, _ in
        for _ in 0..<320 {
          let remaining = frontier - game.commander.flightSimulation.physicalTime
          if remaining <= 1e-9 { break }
          try empUnitFrame(&game, delta: min(0.1, remaining), publish: publish)
        }
      }
      let attained = try #require(game.commander.savedEMPState?.records[logical]?
        .hull.body.physical?.currentNewtKitStock)
      try #require(abs(game.commander.flightSimulation.physicalTime - frontier) <= 1e-9)
      try #require(attained.phase == .actuating && attained.interruptedAt == nil)
      try #require(attained.work.loweredFraction > 0 && attained.work.loweredFraction < 1)
    }
    let currentBodyCandidate = game.bodies.first { $0.physical?.identity == physical.identity }
    let currentBody = try #require(currentBodyCandidate)
    let model = game.modelPose(of: currentBody)
    let profileCandidate = physical.catalogueShipID.flatMap { SalvageCatalogue.empProfile(catalogueShipID: $0) }
    let profile = try #require(profileCandidate)
    let sectionCandidate = profile.sections.first { $0.kind == .cargo }
    let section = try #require(sectionCandidate)
    let normal = model.orientation.apply(section.normal).unit
    var orientation = Basis3()
    orientation.z = normal * -1
    let up = abs(orientation.z.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
    orientation.x = up.cross(orientation.z).unit
    orientation.y = orientation.z.cross(orientation.x).unit
    NativePagedSalvageFixture.moveObserver(&game, to: .init(
      position: model.systemPoint(section.localPosition) + normal * 200, orientation: orientation))
    let retainedCandidate = game.bodies.first { $0.physical?.identity == physical.identity }
    let retained = try #require(retainedCandidate)
    #expect((game.modelPose(of: retained).position - model.position).length < 1e-7)
    #expect(retained.physical == currentBody.physical)
    game.selectFlightTool(.salvageCutter)
    game.speed = 0
    let ownedPreparationRequired9 = try game.nearestMissionCollision(from: .init(0, 0, 0), direction: .init(0, 0, 1),
      range: 300, radius: 0, includePlayer: false)?.hit.target == .body(body.id)
    try #require(ownedPreparationRequired9)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    if stage == "moving-writer" {
      let files = try ScriptFinanceTestFixture.files(storage.directory)
      let time = await runtime.snapshot().commander.flightSimulation.physicalTime
      try storage.blockWriter()
      _ = await NativePeopleTestFixture.capture(runtime)
      let failed = await runtime.snapshot()
      let record = try #require(failed.commander.savedEMPState?.records[stock.issue.person.source])
      let untouched = try #require(record.hull.body.physical?.currentNewtKitStock)
      let source = try #require(CurrentNewtKitSource.current)
      let parentCandidate = failed.bodies.first { $0.physical?.identity == record.hull.binding }
      let parent = try #require(parentCandidate)
      #expect(failed.commander.flightSimulation.physicalTime > time)
      #expect(failed.commander.nativePeople == nil && record.crewCaptures.isEmpty && record.pods.isEmpty)
      #expect(record.crewOutcome(ordinal: stock.issue.person.ordinal) == .aboard)
      #expect(untouched.interruptedAt == nil && untouched.phase == .actuating)
      #expect(source.matchesAttachedObservation(stock: untouched, state: failed.currentNewtBodyState(parent),
        at: failed.commander.flightSimulation.physicalTime))
      #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
      try storage.restoreWriter()
      try await runtime.save(to: storage.url)
    }
    let beforeCapture = await runtime.snapshot()
    let beforeParentCandidate = beforeCapture.bodies.first { $0.physical?.identity == physical.identity }
    let beforeParent = try #require(beforeParentCandidate)
    let ownedPreparationRequired10 = beforeCapture.currentNewtCellComponentContract(for: beforeParent)
    let occupied = try #require(ownedPreparationRequired10)
    _ = await NativePeopleTestFixture.capture(runtime)
    let captured = await runtime.snapshot()
    let record = try #require(captured.commander.savedEMPState?.records[stock.issue.person.source])
    try #require(record.crewOutcome(ordinal: stock.issue.person.ordinal) == .captured)
    try #require(record.crewCaptures.count == 1 && record.pods.isEmpty)
    try #require(captured.commander.nativePeople?.admissions.contains {
      $0.person == .emp(stock.issue.person) && $0.origin == .capturedCrew
    } == true)
    try #require(record.hull.body.physical?.currentNewtKitStock?.issue == stock.issue)
    if stage != "stowed" {
      let source = try #require(CurrentNewtKitSource.current)
      let stopped = try #require(record.hull.body.physical?.currentNewtKitStock)
      let a = try #require(stopped.actuation)
      let time = captured.commander.flightSimulation.physicalTime
      let incoming = try #require(source.motion(a, at: time))
      let actualParentCandidate = captured.bodies.first { $0.physical?.identity == record.hull.binding }
      let actualParent = try #require(actualParentCandidate)
      let actual = captured.currentNewtBodyState(actualParent)
      let beforeStock = try #require(beforeParent.physical?.currentNewtKitStock)
      let moving = try #require(source.components(stock: beforeStock, work: stopped.work,
        at: time, parent: incoming.parent, load: a.load, cell: occupied))
      // Audit the instantaneous internal brake before the existing person custody
      // transfer. Use actual retained parent motion and all original source parts.
      let locked = moving.map { part in
        CurrentNewtKitComponent(id: part.id, collisionMesh: part.collisionMesh,
          displayMesh: part.displayMesh, pose: part.pose, massProperties: part.massProperties,
          velocity: actual.velocity + actual.angularVelocity.cross(part.pose.position - actual.pose.position),
          angularVelocity: actual.angularVelocity)
      }
      let prior = try #require(CurrentNewtComponentMechanics.momentum(moving, about: actual.pose.position))
      let after = try #require(CurrentNewtComponentMechanics.momentum(locked, about: actual.pose.position))
      #expect((actual.pose.position - incoming.parent.pose.position).length < 1e-7)
      #expect((actual.pose.orientation.x - incoming.parent.pose.orientation.x).length < 1e-9)
      #expect((actual.pose.orientation.y - incoming.parent.pose.orientation.y).length < 1e-9)
      #expect((actual.pose.orientation.z - incoming.parent.pose.orientation.z).length < 1e-9)
      #expect((prior.linearMomentum - after.linearMomentum).length
        <= max(1e-7, 1024 * Double.ulpOfOne * prior.linearMomentum.length))
      #expect((prior.angularMomentum - after.angularMomentum).length
        <= max(1e-7, 1024 * Double.ulpOfOne * prior.angularMomentum.length))
      #expect(after.kineticEnergyJoules <= prior.kineticEnergyJoules
        + max(1e-6, 1024 * Double.ulpOfOne * prior.kineticEnergyJoules))
      #expect(stopped.interruptedAt == time && time < a.unlockAt)
      #expect(stopped.work == source.work(at: time, actuation: a, interruptedAt: time))
      #expect(stopped.issue == stock.issue && stopped.receipt == nil)
    }
    return runtime
  }
}
