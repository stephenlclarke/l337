import Foundation
import Testing

@testable import L337Core

@Suite(.serialized)
struct OriginalFleetMainStationDiscoveryTests {
  @Test func selectedActualMainSourceRecordsAnEncounterWithoutACollectionGrant() throws {
    var game = try NativeStationTestFixture.launched(withDockingComputer: true)
    try #require(game.commander.targetingTier == .docking)
    try faceOriginalMainStation(&game, distance: 2000)
    let station = try #require(game.bodies.first { $0.id == 0 })
    try #require(station.hull == .station && station.physical?.catalogueShipID == nil)
    try #require(station.nativeStationIdentity == nil)
    guard case .living(let destination) = game.nativeOriginalMainStationDestination else {
      Issue.record("Actual main station must have its current typed destination")
      return
    }
    #expect(destination.observation.actor == station.physical?.identity)
    let layout = CockpitLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
    try #require(Display.visibleInFront(station, game: game, layout: layout))
    let context = try #require(game.gameplayContext())
    try #require(station.position.length <= context.perceptionRadius)
    let collision = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: station.position.unit,
      range: station.position.length + (game.gameplayMesh(for: station).vertices.map(\.length).max() ?? 0),
      radius: 0, includePlayer: false)
    let hit = try #require(collision)
    try #require(hit.hit.target == .body(station.id))
    selectOriginalMainStation(&game, station: station)
    try #require(game.autoTargetBody == station)
    let baseline = game
    for refusal in MainFlightRefusal.allCases {
      var refused = baseline
      switch refusal {
      case .duplicate:
        refused.bodies.append(station)
      case .foreignTag:
        let index = try #require(refused.bodies.firstIndex { $0.id == 0 })
        refused.bodies[index].physical?.catalogueShipID = "SH002"
      case .foreignWorld:
        refused.commander.nativeStations = try NativeStationWorld(owner: UUID())
      case .missingObservation:
        refused.commander.nativeStations?.mainObservations = []
      case .behindPlayer:
        var pose = refused.commander.flightSimulation.pose
        pose.orientation.x = pose.orientation.x * -1
        pose.orientation.z = pose.orientation.z * -1
        NativeStationTestFixture.reframe(&refused, to: pose)
      }
      let commander = refused.commander
      refused.observeSelectedFleetDiscovery()
      #expect(refused.commander == commander, Comment(rawValue: refusal.rawValue))
    }
    let commander = game.commander
    game.observeSelectedFleetDiscovery()
    let discovery = try #require(game.commander.scriptState.savedFleetDiscovery)
    let entry = try #require(discovery.entries["SH028"])
    #expect(discovery.valid && entry.valid && entry.status == "Encountered")
    #expect(entry.encounter.kind == .encounter && entry.encounter.actor == station.physical?.identity)
    #expect(entry.encounter.player == context.player.identity)
    #expect(entry.identification == nil && entry.milestone == nil)
    #expect(entry.encounter.mainDock == nil && entry.encounter.secondaryDock == nil)
    #expect(game.commander.nativeStations?.currentMainDock == nil)
    #expect(game.commander.fleetBlueprintAcquisition(for: "SH028") == nil)
    var unchanged = game.commander
    unchanged.scriptState.savedFleetDiscovery = commander.scriptState.savedFleetDiscovery
    #expect(unchanged == commander)
    game.observeSelectedFleetDiscovery()
    #expect(game.commander.scriptState.savedFleetDiscovery == discovery)
  }

  @Test func actualDoorwayCollectsMainStationAndPreservesHistoryAcrossColdLoad() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.launched()
    try faceOriginalMainStation(&game, distance: 2)
    let captured = try #require(game.bodies.first { $0.id == 0 })
    let secondary = try #require(game.bodies.first { $0.nativeStationIdentity != nil })
    let player = try #require(game.commander.flightSimulation.player)
    try #require(captured.physical?.catalogueShipID == nil)
    game.speed = 3
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    for _ in 0..<100 where !game.docked { game = await runtime.advance(delta: 0.01) }
    try #require(game.docked && game.dockedAtMainStation && game.bodies.isEmpty)
    let receipt = try #require(game.commander.nativeStations?.currentMainDock)
    try #require(game.nativeMainStationDockEvidenceIsCurrent)
    let arrival = try #require(game.nativeMainStationArrivalContext(for: receipt.station))
    #expect(game.acceptsNativeMainStationArrivalContext(arrival))
    #expect(receipt.actor == captured.physical?.identity && receipt.actor == arrival.destination.observation.actor)
    #expect(receipt.actor == game.commander.flightSimulation.anchors?.station.identity)
    #expect(game.commander.nativeStations?.ledger.currentDock == nil)
    let discovery = try #require(game.commander.scriptState.savedFleetDiscovery)
    let entry = try #require(discovery.entries["SH028"])
    let proof = try #require(entry.milestone)
    #expect(discovery.valid && entry.valid && proof.valid)
    #expect(proof.kind == .stationDocking && proof.mainDock == receipt && proof.secondaryDock == nil)
    #expect(proof.actor == receipt.actor && proof.player == player)
    #expect(entry.status == "Collection milestone recorded")
    #expect(discovery.readout(for: "SH028").contains("Collection: Collection milestone recorded"))
    #expect(game.commander.fleetBlueprintAcquisition(for: "SH028") == nil)

    // Reuse this one genuine arrival; altered copies never mint another docking receipt.
    for refusal in MainDockRefusal.allCases {
      var refused = game
      refused.commander.scriptState.savedFleetDiscovery = nil
      var body = captured
      switch refusal {
      case .secondaryBody:
        body = secondary
      case .wrongBodyNumber:
        body.id = secondary.id
      case .playerActor:
        let physical = try #require(body.physical)
        body.physical = .init(identity: player, population: physical.population)
      case .foreignTag:
        body.physical?.catalogueShipID = "SH002"
      case .foreignWorld:
        refused.commander.nativeStations = try NativeStationWorld(owner: UUID())
      case .missingReceipt:
        refused.commander.nativeStations?.currentMainDock = nil
      case .staleEpoch:
        refused.nativeStationRuntimeEpoch = UUID()
      }
      let commander = refused.commander
      refused.observeFleetDocking(body: body, main: receipt)
      #expect(refused.commander == commander, Comment(rawValue: refusal.rawValue))
    }
    var replay = game
    replay.commander.scriptState.savedFleetDiscovery = nil
    replay.observeFleetDocking(body: captured, main: receipt)
    #expect(replay.commander.scriptState.savedFleetDiscovery == discovery)
    #expect(replay.commander == game.commander)
    try await runtime.save(to: storage.url)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: storage.url)
    #expect(saved.scriptState.savedFleetDiscovery == discovery)
    let cold = GameRuntime(game: Game(executive: false), saveURL: storage.url)
    try await cold.load(from: storage.url, persistMigrations: false)
    let restored = await cold.snapshot().commander
    #expect(restored == saved && restored.scriptState.savedFleetDiscovery == discovery)
    #expect(restored.scriptState.savedFleetDiscovery?.entries["SH028"]?.milestone == proof)
    #expect(restored.fleetBlueprintAcquisition(for: "SH028") == nil)
  }
}

private enum MainFlightRefusal: String, CaseIterable {
  case duplicate, foreignTag, foreignWorld, missingObservation, behindPlayer
}
private enum MainDockRefusal: String, CaseIterable {
  case secondaryBody, wrongBodyNumber, playerActor, foreignTag, foreignWorld, missingReceipt, staleEpoch
}

private func faceOriginalMainStation(_ game: inout Game, distance: Double) throws {
  let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
  let old = game.commander.flightSimulation.pose
  var pose = ShipPose()
  pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * distance)
  pose.orientation.y = old.orientation.apply(station.entranceUp)
  pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
  pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
  NativeStationTestFixture.reframe(&game, to: pose)
}

private func selectOriginalMainStation(_ game: inout Game, station: SpaceBody) {
  game.autoPilot.cycle(
    [station], frontIDs: [station.id], signature: "actual-main-station-discovery",
    origin: game.commander.flightSimulation.player)
  game.screen = .front
}
