import Foundation
import Testing

@testable import L337Core

struct NativeC03CommissioningEvidenceUnitTests {
  @Test func actualOrdinarySaleAndNararganBerthPrepareOnlyTheOriginalBirth() async throws {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let starter = GameRuntime(game: Game(executive: false))
    try await starter.startNewCommander()
    _ = try await starter.registerNewCommanderDestination(at: files.save)
    var game = await starter.snapshot()
    try #require(game.nativeMainStationDockEvidenceIsCurrent)
    let market = game.market
    let cargo = game.commander.cargo
    let credits = game.commander.availableCredits
    let commodity = try #require(market.indices.first {
      Commodity.all[$0].unit == "t" && market[$0].quantity > 0
        && market[$0].price <= credits && cargo[$0] == 0
    })
    game.screen = .buy
    game.selection = commodity
    game.trade(buy: true)
    try #require(game.commander.cargo[commodity] == 1)
    #expect(game.commander.scriptState.firstNativeCommoditySale == nil)

    var wrongBerth = game
    wrongBerth.screen = .sell
    wrongBerth.trade(buy: false)
    try #require(wrongBerth.commander.scriptState.firstNativeCommoditySale != nil)
    #expect(NativeC03CommissioningEvidence.current(in: wrongBerth) == nil)

    try placeOnControlledNararganApproach(&game)
    #expect(NativeC03CommissioningEvidence.current(in: game) == nil)
    let arrival = GameRuntime(game: game, saveURL: files.save)
    for _ in 0..<100 {
      if await arrival.snapshot().docked { break }
      _ = await arrival.advance(delta: 0.05)
    }
    var berthed = await arrival.snapshot()
    try #require(berthed.nativeMainStationDockEvidenceIsCurrent)
    try #require(berthed.systemIdentity == NativeHollowManifestDefinition.issuer)
    #expect(NativeC03CommissioningEvidence.current(in: berthed) == nil)

    berthed.screen = .sell
    berthed.selection = commodity
    let stock = berthed.market[commodity].quantity
    let cash = berthed.commander.credits
    let bid = berthed.market[commodity].bidPrice
    berthed.trade(buy: false)
    try #require(berthed.commander.cargo[commodity] == 0)
    #expect(berthed.market[commodity].quantity == stock + 1)
    #expect(berthed.commander.credits == cash + bid)

    let before = berthed.commander
    let evidence = try #require(NativeC03CommissioningEvidence.current(in: berthed))
    let birth = try evidence.prepareBirth(in: berthed)
    let retry = try evidence.prepareBirth(in: berthed)
    #expect(retry == birth && birth.input.dock == evidence.arrival.receipt)
    #expect(birth.input.sale == before.scriptState.firstNativeCommoditySale)
    #expect(birth.originals.count == 2 && birth.operations.count == 7)
    #expect(Set(birth.originals.map(\.hull)).count == 2)
    #expect(Set(birth.originals.map(\.captain)).count == 2)
    #expect(birth.originals.allSatisfy { $0.master == birth.master.id })
    #expect(birth.operations.map(\.sequence) == Array(UInt64(1)...7))
    #expect(berthed.commander == before && berthed.commander.scriptState.instances.isEmpty)
    #expect(berthed.commander.scriptState.savedClueJournal == nil)
    var paused = berthed
    paused.paused = true
    #expect(throws: SaveError.invalidCommander) { try evidence.prepareBirth(in: paused) }
    var trial = berthed
    trial.trialTitle = "Negative isolated context"
    #expect(NativeC03CommissioningEvidence.current(in: trial) == nil)

    let bytes = try NativeHollowManifestBirthCodec.encode(birth)
    let decoded = try NativeHollowManifestBirthCodec.decode(
      bytes, owner: birth.input.owner, mission: birth.input.mission, existingBirth: birth)
    #expect(decoded == birth)
    let writer = GameRuntime(game: berthed, saveURL: files.save)
    try await writer.save(to: files.save)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: files.save, persistMigrations: false)
    let restored = await cold.snapshot()
    #expect(throws: SaveError.invalidCommander) { try evidence.prepareBirth(in: restored) }
    let fresh = try #require(NativeC03CommissioningEvidence.current(in: restored))
    #expect(fresh.arrival.runtimeEpoch != evidence.arrival.runtimeEpoch)
    #expect(try fresh.prepareBirth(in: restored) == birth)
    #expect(
      NativeHollowManifestBirthCodec.historicalOwnerMatches(
        decoded, commander: restored.commander, mission: birth.input.mission))
    #expect(restored.commander.scriptState.instances.isEmpty)
    #expect(restored.commander.scriptState.savedClueJournal == nil)
  }

  /// Only the remote test placement is controlled. The native berth must really be attained.
  private func placeOnControlledNararganApproach(_ game: inout Game) throws {
    game.screen = .status
    game.launch()
    try #require(!game.docked)
    try game.departOrdinarySimulation()
    let world = NativeHollowManifestDefinition.issuer
    game.commander.galaxy = world.galaxy
    game.commander.system = world.system
    game.selectedSystem = world.system
    game.systems = Universe.systemsIncludingPlugh(number: world.galaxy)
    game.speed = 0
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    let beganVisit = game.beginGameplayVisit(arriving: true)
    try #require(beganVisit)
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
  }
}
