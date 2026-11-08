import Foundation
import Testing

@testable import L337Core

struct NavalPlansCourierPersistenceUnitTests {
  @Test func actualPlansCollectionAndDeliverySurviveColdLoadWithoutAmbushActors() async throws {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let starter = GameRuntime(game: Game(executive: false))
    try await starter.startNewCommander()
    _ = try await starter.registerNewCommanderDestination(at: files.save)
    var approach = await starter.snapshot()
    let entry = try #require(approach.missionPacks.entries.first { $0.pack.id == "xyzzy.plans" })

    // Start with previously issued orders. The two remote placements are controlled.
    // Collection and delivery both require the real native swept station entry below.
    approach.commander.missionStage = .reportToCeerdi
    approach.commander.kills = 1280
    let before = approach.commander
    try prepareApproach(&approach, system: 83)
    let collection = GameRuntime(game: approach, saveURL: files.save)
    let collected = try await awaitMainBerth(collection, system: 83)
    try #require(collected.commander.missionStage == .carryingPlans)
    try #require(collected.missionNotice?.message == .plansCollection)
    let carried = try #require(collected.commander.missionProgress[entry.pack.stateID])
    #expect(carried.stage == "carrying" && carried.digest == entry.digest)
    #expect(carried.receipts.contains("transition.collection"))
    #expect(collected.commander.cargo == before.cargo)
    #expect(collected.commander.credits == before.credits)
    #expect(collected.commander.kills == 1280)
    try await closeNavalMessage(collection)
    let savedSimulation = await collection.snapshot().scriptSimulationSave
    try await collection.save(to: files.save)

    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: files.save, persistMigrations: false)
    var continued = await cold.snapshot()
    try #require(continued.nativeMainStationDockEvidenceIsCurrent)
    #expect(continued.commander.missionStage == .carryingPlans && continued.packMatchesSave(entry))
    #expect(continued.commander.missionProgress[entry.pack.stateID] == carried)
    #expect(continued.bodies.allSatisfy {
      $0.physical?.catalogueShipID != "SH124" && $0.physical?.catalogueShipID != "SH125"
        && $0.hull != .thargoid && $0.hull != .thargon
    })
    #expect(continued.scriptSimulationSave.randomState == savedSimulation.randomState)
    #expect(continued.scriptSimulationSave.missionLoopCounter == savedSimulation.missionLoopCounter)
    #expect(continued.scriptSimulationSave.missionSpawnDelay == savedSimulation.missionSpawnDelay)
    try prepareApproach(&continued, system: 36)
    let delivery = GameRuntime(game: continued, saveURL: files.save)
    let delivered = try await awaitMainBerth(delivery, system: 36)
    try #require(delivered.commander.missionStage == .plansDelivered)
    let complete = try #require(delivered.commander.missionProgress[entry.pack.stateID])
    #expect(complete.stage == "complete" && complete.digest == carried.digest)
    #expect(complete.receipts == carried.receipts.union(["transition.delivery"]))
    #expect(delivered.commander.kills == 1536 && delivered.commander.credits == before.credits)
    #expect(delivered.commander.cargo == before.cargo)
    #expect(delivered.commander.equipment.contains(Equipment.navalEnergyUnit))
    #expect(delivered.missionEncounter("plans-ambush") == nil)
    try await closeNavalMessage(delivery)
    try await delivery.save(to: files.save)

    let finalRuntime = GameRuntime(game: Game(executive: false))
    try await finalRuntime.load(from: files.save, persistMigrations: false)
    var repeated = await finalRuntime.snapshot()
    try #require(repeated.nativeMainStationDockEvidenceIsCurrent)
    let completed = repeated.commander
    repeated.progressNavalMissions()
    #expect(repeated.commander == completed)
    #expect(completed.missionProgress[entry.pack.stateID] == complete)
    #expect(repeated.missionNotice == nil)
  }

  @Test func exactLarvaalProfilesRemainOutsideTheLiveAmbushUntilAdmitted() throws {
    let warship = try #require(OriginalFleetR3Data.contract(for: "SH124"))
    let drone = try #require(OriginalFleetR3Data.contract(for: "SH125"))
    let warshipCrew = try #require(warship.accommodation)
    let droneCrew = try #require(drone.accommodation)
    let warshipFit = try #require(warship.fitting)
    let droneFit = try #require(drone.fitting)
    let warshipPerformance = try #require(warship.performance)
    let dronePerformance = try #require(drone.performance)
    #expect(warship.family == "larvaal-warship" && drone.family == "larvaal-drone")
    #expect(warshipCrew.nativeCrew == 4 && !warshipCrew.nativeAutonomous)
    #expect(droneCrew.nativeCrew == 0 && droneCrew.nativeAutonomous)
    #expect(warshipFit.recommendedRoleKit == ["combatLaser", "ECM"])
    #expect(droneFit.recommendedRoleKit == ["miningLaser", "cargoScoop"])
    #expect(!warshipFit.roleKitIncluded && !droneFit.roleKitIncluded)
    #expect(warshipPerformance.missiles == 8 && dronePerformance.missiles == 4)

    for (id, faces) in [(warship.id, 1464), (drone.id, 5112)] {
      #expect(OriginalFleetRuntimeHullSource.source(for: id) == nil)
      #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
        id: id, actualSourceFaces: faces, maximum: 512
      )) {
        try OriginalDetailedHullStage.requireRuntime(id)
      }
    }
  }

  private func prepareApproach(_ game: inout Game, system: Int) throws {
    game.screen = .status
    game.launch()
    try #require(!game.docked)
    try game.departOrdinarySimulation()
    game.commander.galaxy = 2
    game.commander.system = system
    game.selectedSystem = system
    game.systems = Universe.systemsIncludingPlugh(number: 2)
    game.speed = 0
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    let began = game.beginGameplayVisit(arriving: true)
    try #require(began)
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

  private func awaitMainBerth(_ runtime: GameRuntime, system: Int) async throws -> Game {
    for _ in 0..<100 {
      let current = await runtime.snapshot()
      if current.docked {
        try #require(current.nativeMainStationDockEvidenceIsCurrent)
        try #require(current.systemIdentity == SystemIdentity(galaxy: 2, system: system))
        return current
      }
      #expect(current.bodies.allSatisfy { $0.hull != .thargoid && $0.hull != .thargon })
      _ = await runtime.advance(delta: 0.05)
    }
    throw SaveError.invalidCommander
  }

  private func closeNavalMessage(_ runtime: GameRuntime) async throws {
    for _ in 0..<48 { _ = await runtime.advance(delta: 0.05) }
    await runtime.key("escape")
    let closed = await runtime.snapshot()
    try #require(closed.screen == .status)
  }
}
