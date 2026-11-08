import Foundation
import Testing

@testable import L337Core

struct NativeTitheCommissionHistoryUnitTests {
  @Test func actualOrdinarySalesRetainTwoDistinctWitnessesAcrossCurrentSaveAndLoad() async throws {
    let start = GameRuntime(game: Game(executive: false))
    try await start.startNewCommander()
    var game = await start.snapshot()
    try #require(game.commander.valid && game.nativeMainStationDockEvidenceIsCurrent)
    let original = try NativeTitheCommissionHistory.current(in: game)
    #expect(original.retainedOrdinarySaleCount == 0 && !original.hasRequiredVisitHistory)
    #expect(!original.atRakenorMainBerth)

    let market = game.market
    let cargo = game.commander.cargo
    let credits = game.commander.availableCredits
    let index = try #require(market.indices.first {
      Commodity.all[$0].unit == "t" && market[$0].quantity >= 2
        && market[$0].price > 0 && market[$0].price <= credits / 2 && cargo[$0] == 0
    })
    game.screen = .buy
    game.selection = index
    game.trade(buy: true)
    game.trade(buy: true)
    try #require(game.commander.cargo[index] == 2)
    try #require(game.commander.scriptState.firstNativeCommodityTrade?.side == .buy)
    #expect(try NativeTitheCommissionHistory.current(in: game).retainedOrdinarySaleCount == 0)

    game.screen = .sell
    for expectedCargo in [1, 0] {
      let stock = game.market[index].quantity
      let cash = game.commander.credits
      let bid = game.market[index].bidPrice
      game.trade(buy: false)
      try #require(game.commander.cargo[index] == expectedCargo)
      #expect(game.market[index].quantity == stock + 1)
      #expect(game.commander.credits == cash + bid)
    }
    let beforeReview = game.commander
    let history = try NativeTitheCommissionHistory.current(in: game)
    let first = try #require(history.firstSale)
    #expect(first.before.cargo == 2 && first.after.cargo == 1)
    let second = try #require(history.secondSale)
    #expect(second.firstOperation == first.operation && second.sale.operation != first.operation)
    #expect(second.sale.before.cargo == 1 && second.sale.after.cargo == 0)
    #expect(history.retainedOrdinarySaleCount == NativeTitheCommissionHistory.requiredOrdinarySales)
    #expect(game.commander == beforeReview)

    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: game)
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    try await runtime.save(to: files.save)
    let (stored, _) = try ScriptSaveStore.read(Data(contentsOf: files.save), from: files.save)
    #expect(stored.scriptState.firstNativeCommoditySale == first)
    try await runtime.load(from: files.save, persistMigrations: false)
    let restored = await runtime.snapshot()
    #expect(try NativeTitheCommissionHistory.current(in: restored) == history)
    #expect(restored.commander.scriptState.instances.isEmpty)
    #expect(restored.commander.scriptState.savedClueJournal == nil)
  }

  @Test func emptySaleAndAutomaticTwoTonneSaleDoNotProveTwoTransactionsAfterColdLoad()
    async throws
  {
    let starter = GameRuntime(game: Game(executive: false))
    try await starter.startNewCommander()
    var game = await starter.snapshot()
    try #require(game.commander.valid && game.nativeMainStationDockEvidenceIsCurrent)
    let emptyCargo = game.commander.cargo
    let initialMarket = game.market
    let initialCredits = game.commander.credits
    let commodity = try #require(initialMarket.indices.first {
      Commodity.all[$0].unit == "t" && emptyCargo[$0] == 0
        && initialMarket[$0].quantity >= 2 && initialMarket[$0].price > 0
        && initialMarket[$0].price <= initialCredits / 2
    })
    game.selection = commodity
    game.screen = .sell
    game.trade(buy: false)
    #expect(game.commander.cargo == emptyCargo && game.market == initialMarket)
    #expect(game.commander.credits == initialCredits)
    #expect(try NativeTitheCommissionHistory.current(in: game).retainedOrdinarySaleCount == 0)

    game.screen = .buy
    game.trade(buy: true)
    game.trade(buy: true)
    try #require(game.commander.cargo[commodity] == 2)
    #expect(try NativeTitheCommissionHistory.current(in: game).retainedOrdinarySaleCount == 0)
    let stock = game.market[commodity].quantity
    let bid = game.market[commodity].bidPrice
    let credits = game.commander.credits
    game.autoTrade()
    let history = try NativeTitheCommissionHistory.current(in: game)
    let sale = try #require(history.firstSale)
    // Later refuelling and export purchases may change live balances again.
    #expect(sale.commodity == commodity && sale.quantity == 2 && sale.unitPrice == bid)
    #expect(sale.before == NativeSaleBalance(stock: stock, cargo: 2, credits: credits))
    #expect(sale.after == NativeSaleBalance(stock: stock + 2, cargo: 0, credits: credits + 2 * bid))
    #expect(history.retainedOrdinarySaleCount == 1)

    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let writer = GameRuntime(game: game)
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try await writer.registerNewCommanderDestination(at: files.save)
    try await writer.save(to: files.save)
    let cold = GameRuntime(game: Game(executive: false))
    let unopened = await cold.snapshot()
    #expect(unopened.commander.scriptState.firstNativeCommoditySale == nil)
    try await cold.load(from: files.save, persistMigrations: false)
    let restored = await cold.snapshot()
    try #require(restored.commander.valid && restored.nativeMainStationDockEvidenceIsCurrent)
    let restoredHistory = try NativeTitheCommissionHistory.current(in: restored)
    #expect(restoredHistory == history)
    #expect(
      restoredHistory.retainedOrdinarySaleCount < NativeTitheCommissionHistory.requiredOrdinarySales)
    #expect(restored.commander.scriptState.instances.isEmpty)
    #expect(restored.commander.scriptState.savedClueJournal == nil)
  }

  @Test func nativeSystemHistoryDeduplicatesRevisitsAndRequiresActualRakenorDock() async throws {
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    var game = await runtime.snapshot()
    game.screen = .status
    game.launch()
    try #require(!game.docked)
    for system in [20, 69, 245, 105] {
      try observeNativeScene(&game, world: .init(galaxy: 6, system: system))
    }
    let inFlight = try NativeTitheCommissionHistory.current(in: game)
    #expect(inFlight.hasRequiredVisitHistory && inFlight.visitedSystems.count == 5)
    #expect(inFlight.retainedOrdinarySaleCount == 0 && !inFlight.atRakenorMainBerth)

    try observeNativeScene(&game, world: .init(galaxy: 6, system: 105))
    #expect(try NativeTitheCommissionHistory.current(in: game) == inFlight)
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
    let arrival = GameRuntime(game: game)
    for _ in 0..<100 {
      if await arrival.snapshot().docked { break }
      _ = await arrival.advance(delta: 0.05)
    }
    let arrived = await arrival.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    let docked = try NativeTitheCommissionHistory.current(in: arrived)
    #expect(docked.atRakenorMainBerth && docked.visitedSystems == inFlight.visitedSystems)
    #expect(docked.retainedOrdinarySaleCount == 0)
    var trial = arrived
    trial.trialTitle = "Negative isolated context"
    #expect(throws: SaveError.invalidCommander) {
      try NativeTitheCommissionHistory.current(in: trial)
    }
    #expect(arrived.commander.scriptState.instances.isEmpty)
  }

  /// Controlled remote scenes use real native visit and station producers.
  private func observeNativeScene(_ game: inout Game, world: SystemIdentity) throws {
    game.persistScriptActors(unloading: true)
    try game.departOrdinarySimulation()
    game.commander.galaxy = world.galaxy
    game.commander.system = world.system
    game.selectedSystem = world.system
    game.systems = Universe.systemsIncludingPlugh(number: world.galaxy)
    game.speed = 0
    game.screen = .front
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    let beganVisit = game.beginGameplayVisit(arriving: true)
    try #require(beganVisit)
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    try #require(game.commander.nativeStations?.mainObservations.contains {
      $0.station.system == world && $0.actor.visit == game.commander.flightSimulation.visit
    } == true)
  }
}
