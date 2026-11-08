import Foundation
import Testing

@testable import L337Core

struct CurrentNewtBisonCustodyTests {
  @Test
  func actualCaptureOfZeroAndOneThenPersonSevenUnlockUsesIndependentCellAndKeepsOriginalTwo() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.disabled(large: true, seed: 31)
    let logical = try NativePeopleTestFixture.source(game)
    let initial = try #require(game.commander.savedEMPState?.records[logical])
    let born = try #require(initial.hull.body.physical?.currentNewtKitStock)
    try #require(born.phase == .stowed && born.issue.person.ordinal == 7 && initial.crewTotal == 12)
    let source = try #require(CurrentNewtKitSource.source(for: born.issue))
    let schedule = try #require(initial.disableEpisodes.last)
    try #require(schedule.ejections[7].delay == 0.5 && schedule.ejections[0].delay > 20)
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 2
    // The existing fixture must aim by moving only the observer against the real
    // born hull/first face; it may not reorient/reposition that hull or its kit.
    try NativePeopleTestFixture.aimCutter(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    var captured = await NativePeopleTestFixture.capture(runtime)
    let partial = try #require(captured.commander.savedEMPState?.records[logical])
    try #require(partial.crewOutcome(ordinal: 0) == .captured && partial.crewOutcome(ordinal: 1) == .captured)
    #expect(partial.crewOutcome(ordinal: 7) == .aboard && partial.crewOutcome(ordinal: 2) == .aboard)
    try expectMass(captured, logical: logical,
      reference: CurrentBisonWideShoePhysicalSource.captured01Person7StillAboard)
    let cells = try #require(source.carrierCells(issue: born.issue,
      load: try #require(captured.currentNewtKitLoad(for: partial.hull.body)),
      at: captured.commander.flightSimulation.physicalTime))
    #expect(cells[0].originalOccupant == nil && cells[1].originalOccupant == nil)
    #expect(cells[2].originalOccupant?.ordinal == 2 && cells[7].originalOccupant == nil)
    #expect(cells.allSatisfy { $0.electricalJoules < 1_380_000 })
    // Preserve the existing census fixture's ten native frames. The real sampled
    // delay starts the mechanism; no saved receipt or future pose is installed.
    for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
    captured = await runtime.snapshot()
    let after = try #require(captured.commander.savedEMPState?.records[logical])
    let stock = try #require(after.hull.body.physical?.currentNewtKitStock)
    let receipt = try #require(stock.receipt)
    #expect(stock.issue == born.issue && stock.phase == .released && stock.remaining == 0)
    #expect(receipt.releasedAt == receipt.actuation.startedAt && receipt.energyJoules == 0)
    #expect(receipt.issue.person.ordinal == 7 && receipt.podSpawn.member == 8)
    #expect(receipt.podActor != receipt.actuation.parent)
    #expect(receipt.podMass.massKilograms == 352.5)
    #expect(stock.work.rodMetres == source.stroke && stock.work.rodVelocity == 0)
    #expect(stock.work.guideWorkJoules == 0 && stock.work.ejectionWorkJoules == 2400)
    #expect(stock.charges.ejectionMechanicalJoules == 600)
    #expect(after.crewOutcome(ordinal: 2) == .aboard && after.crewOutcome(ordinal: 7) == .occupiedPod)
    let podIndex = try #require(after.podIndex(for: 7))
    #expect(podIndex != 7 && after.pods[podIndex].body.physical?.currentNewtKitReceipt == receipt)
    #expect(after.pods[podIndex].body.physical?.empCrewPod == born.issue.person)
    #expect(after.crewAboard + after.pods.count + after.capturedCrewCount + after.lostCrewCount == 12)
    try expectMass(captured, logical: logical,
      reference: CurrentBisonWideShoePhysicalSource.captured01Person7StrokeComplete)
    #expect(after.valid && captured.commander.valid)
    try await runtime.save(to: storage.url)
    let cold = GameRuntime()
    try await cold.load(from: storage.url, persistMigrations: false)
    let loaded = await cold.snapshot()
    let retained = try #require(loaded.commander.savedEMPState?.records[logical])
    #expect(retained.hull.body.physical?.currentNewtKitStock == stock)
    #expect(retained.crewCaptures == after.crewCaptures && retained.disableEpisodes == after.disableEpisodes)
    #expect(retained.pods[podIndex].body.physical?.currentNewtKitReceipt == receipt)
    #expect(loaded.commander.nativePeople == captured.commander.nativePeople && loaded.commander.valid)
    // The genuine remaining complement may recover ship electricity at its real
    // deadline. That never renews the independently spent mechanism or person.
    for _ in 0..<320 {
      let frontier = await cold.snapshot()
      if frontier.commander.savedEMPState?.records[logical]?.isRecovered == true { break }
      _ = await cold.advance(delta: 0.1)
    }
    var recoveredGame = await cold.snapshot()
    let recovered = try #require(recoveredGame.commander.savedEMPState?.records[logical])
    try #require(recovered.isRecovered && recovered.crewAboard > 0)
    let recoveredActor = try #require(recovered.hull.binding)
    let ordinary = try #require(recoveredGame.bodies.first { $0.physical?.identity == recoveredActor })
    let spent = try #require(ordinary.physical?.currentNewtKitStock)
    #expect(ordinary.physical?.empSource == nil)
    #expect(recoveredGame.commander.npcPersistence.logicalIdentity(for: recoveredActor) == logical)
    #expect(spent.issue == born.issue && spent.receipt == receipt && spent.work == stock.work)
    #expect(spent.charges.doesNotExceed(stock.charges) && spent.remaining == 0)
    #expect(spent.validForNPC(catalogueShipID: "SH005", actor: recoveredActor,
      physicalTime: recoveredGame.commander.flightSimulation.physicalTime))
    let world = recoveredGame.modelPose(of: ordinary)
    NativePagedSalvageFixture.moveObserver(&recoveredGame, to: .init(
      position: world.position + .init(50000, 0, 0),
      orientation: recoveredGame.commander.flightSimulation.pose.orientation))
    let departing = GameRuntime(game: recoveredGame, saveURL: storage.url)
    _ = await departing.advance(delta: 0.1)
    var parked = await departing.snapshot()
    #expect(!parked.bodies.contains { $0.physical?.identity == recoveredActor })
    let snapshot = try #require(parked.commander.npcPersistence.unboundSnapshots[logical])
    let parkedStock = try #require(snapshot.currentNewtKitStock)
    #expect(parkedStock.issue == spent.issue && parkedStock.receipt == receipt && parkedStock.work == spent.work)
    #expect(parkedStock.charges.doesNotExceed(spent.charges))
    #expect(parked.commander.savedEMPState?.records[logical]?.hull.body.physical?.currentNewtKitStock == parkedStock)
    NativePagedSalvageFixture.moveObserver(&parked, to: .init(
      position: snapshot.position + .init(0, 0, -1000),
      orientation: parked.commander.flightSimulation.pose.orientation))
    let returning = GameRuntime(game: parked, saveURL: storage.url)
    _ = await returning.advance(delta: 0.1)
    let rejoined = await returning.snapshot()
    let rebound = try #require(rejoined.commander.npcPersistence.binding(for: logical))
    let current = try #require(rejoined.bodies.first { $0.physical?.identity == rebound })
    let returnedStock = try #require(current.physical?.currentNewtKitStock)
    #expect(rebound != recoveredActor && returnedStock.issue == spent.issue)
    #expect(returnedStock.receipt == receipt && returnedStock.work == spent.work && returnedStock.remaining == 0)
    #expect(returnedStock.charges.doesNotExceed(parkedStock.charges))
    #expect(rejoined.commander.savedEMPState?.records[logical]?.hull.binding == rebound)
    #expect(rejoined.commander.valid)
    try await returning.save(to: storage.url)
    let finalCold = GameRuntime()
    try await finalCold.load(from: storage.url, persistMigrations: false)
    let final = await finalCold.snapshot()
    #expect(final.commander.npcPersistence.snapshot(for: logical)?.currentNewtKitStock?.issue == spent.issue)
    #expect(final.commander.savedEMPState?.records[logical]?.hull.body.physical?.currentNewtKitStock?.receipt == receipt)
    #expect(final.commander.valid)
  }

  @Test
  func actualCombatDeathKeepsOriginalTwoPhysicalAfterZeroCaptureAndSevenRelease() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.disabled(large: true, seed: 31)
    let logical = try NativePeopleTestFixture.source(game)
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    _ = await NativePeopleTestFixture.capture(runtime)
    for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
    game = await runtime.snapshot()
    let before = try #require(game.commander.savedEMPState?.records[logical])
    try #require(before.crewOutcome(ordinal: 0) == .captured
      && before.crewOutcome(ordinal: 7) == .occupiedPod && before.crewOutcome(ordinal: 2) == .aboard)
    let actor = try #require(before.hull.binding)
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    let stock = try #require(body.physical?.currentNewtKitStock)
    let source = try #require(CurrentNewtKitSource.source(for: stock.issue))
    let player = try #require(game.commander.flightSimulation.player)
    let origin = try #require(game.makeAttackOrigin(owner: player))
    _ = game.applyCombatHit(.init(target: .body(body.id), distance: body.position.length,
      point: body.position), origin: origin, kind: .laser, damage: 10000)
    game.resolveDestroyed()
    let dead = try #require(game.commander.savedEMPState?.records[logical])
    try #require(dead.terminal && dead.crewOutcome(ordinal: 2) == .deceasedWithHull)
    #expect(dead.crewOutcome(ordinal: 0) == .captured && dead.crewOutcome(ordinal: 7) == .occupiedPod)
    let retained = try #require(dead.hull.body.physical?.currentNewtKitStock)
    let load = try #require(game.currentNewtKitLoad(for: dead.hull.body))
    let originalTwo = try #require(stock.issue.birthLoad.people.first { $0.identity.ordinal == 2 })
    #expect(load.people.contains(originalTwo) && originalTwo.profile.massKilograms == 100)
    #expect(!load.people.contains { $0.identity.ordinal == 0 || $0.identity.ordinal == 7 })
    let cell = try #require(game.currentNewtCellComponentContract(for: dead.hull.body))
    let actual = try #require(source.loadedMechanicalMass(stock: retained, load: load, cell: cell))
    let reference = CurrentBisonWideShoePhysicalSource.captured0Person7StrokeComplete
    let inventory = try #require(source.loadModel?.masses(load))
    let expected = try #require(CurrentNewtKitMass.combined([
      .init(massKilograms: reference.massKilograms, centreOfMassMetres: reference.centreMetres,
        inertiaKgM2: reference.inertiaKgM2),
    ] + inventory))
    #expect(source.matchesMass(actual, expected))
    let parts = try #require(source.components(stock: retained, at: dead.hull.physicalTime,
      parent: .init(pose: .init(position: dead.hull.body.position, orientation: dead.hull.body.orientation),
        velocity: try #require(dead.hull.body.physical?.velocity),
        angularVelocity: try #require(dead.hull.body.physical?.angularVelocity)), load: load, cell: cell))
    #expect(parts.contains { $0.id == "original-person-ordinal-2" && $0.massProperties.massKilograms == 100 })
    #expect(!parts.contains { $0.id == "original-person-ordinal-0" || $0.id == "original-person-ordinal-7" })
    #expect(dead.valid && retained.issue == stock.issue && retained.receipt == stock.receipt)
  }

  private func expectMass(_ game: Game, logical: ActorIdentity,
    reference: CurrentBisonWideShoePhysicalSource.MassReference) throws {
    let record = try #require(game.commander.savedEMPState?.records[logical])
    let parent = try #require(record.hull.binding)
    let body = try #require(game.bodies.first { $0.physical?.identity == parent })
    let stock = try #require(body.physical?.currentNewtKitStock)
    let source = try #require(CurrentNewtKitSource.source(for: stock.issue))
    let load = try #require(game.currentNewtKitLoad(for: body))
    let cell = try #require(game.currentNewtCellComponentContract(for: body))
    let actual = try #require(source.loadedMechanicalMass(stock: stock, load: load, cell: cell))
    let inventory = try #require(source.loadModel?.masses(load))
    let expected = try #require(CurrentNewtKitMass.combined([
      .init(massKilograms: reference.massKilograms, centreOfMassMetres: reference.centreMetres,
        inertiaKgM2: reference.inertiaKgM2),
    ] + inventory))
    #expect(source.matchesMass(actual, expected))
    let components = try #require(source.components(stock: stock,
      at: game.commander.flightSimulation.physicalTime, parent: game.currentNewtBodyState(body), load: load, cell: cell))
    #expect(!components.contains { $0.id == "original-person-ordinal-0" || $0.id == "original-person-ordinal-1" })
    #expect(components.contains { $0.id == "original-person-ordinal-2" })
    #expect(components.filter { $0.id == "original-person-ordinal-7" }.count == (stock.phase == .released ? 0 : 1))
  }
}
