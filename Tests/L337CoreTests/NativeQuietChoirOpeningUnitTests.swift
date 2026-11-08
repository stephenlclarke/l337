import Foundation
import Testing

@testable import L337Core

/// Controlled remote scenes, not fuel-paid/flown routes. Bootstrap, native observations
/// and the final swept berth use actual producers. No saved visit, identification, dock,
/// commission, item or consent is injected. This fixture intentionally has no Larvaal ID.
private final class QuietChoirOpeningFixture {
  let files: ScriptFreightFixture
  let runtime: GameRuntime

  init(priorSystems: Int = 3, repeatOneSystem: Bool = false) async throws {
    let storage = try ScriptFreightFixture()
    files = storage
    var ready = false
    defer { if !ready { storage.clean() } }
    try FileManager.default.createDirectory(
      at: storage.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let boot = GameRuntime(game: Game(executive: false))
    try await boot.startNewCommander()
    _ = try await boot.registerNewCommanderDestination(at: storage.save)
    try #require(await boot.snapshot().nativeMainStationDockEvidenceIsCurrent)
    await boot.nativeCommand { $0.screen = .status }
    await boot.key("0")
    var game = await boot.snapshot()
    try #require(!game.docked && game.commander.nativeStations?.currentMainDock == nil)
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledQuietChoirDirectory)]
    for index in 0..<priorSystems {
      game = try Self.observeNativeScene(game,
        world: .init(galaxy: 3, system: 21 + (repeatOneSystem ? 0 : index)))
    }
    game = try Self.observeNativeScene(game, world: NativeQuietChoirDefinition.issuer)
    let station = try #require(game.bodies.first { $0.id == 0 })
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
    runtime = GameRuntime(game: game, saveURL: storage.save)
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    try #require(arrived.systemIdentity == NativeQuietChoirDefinition.issuer)
    try #require(arrived.commander.scriptState.firstNativeCommodityTrade == nil)
    try #require(NativeQuietChoirTravelHistory.identification(in: arrived) == nil)
    try await runtime.save(to: storage.save)
    ready = true
  }

  private static func observeNativeScene(_ original: Game, world: SystemIdentity) throws -> Game {
    var game = original
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
    let state = try #require(game.commander.nativeStations)
    try #require(state.mainObservations.contains {
      $0.station.system == world && $0.actor.visit == game.commander.flightSimulation.visit
    })
    return game
  }

  func clean() { files.clean() }

  func review() async throws -> Game {
    await runtime.nativeCommand { game in
      game.openContractBoard()
      if let index = game.contractBoard.rows.firstIndex(where: { $0.quietChoir == .accept }) {
        game.contractBoard.selection = index
      }
    }
    let board = await runtime.snapshot()
    try #require(board.contractBoard.selected?.quietChoir == .accept)
    await runtime.key("return")
    let detail = await runtime.snapshot()
    try #require(detail.contractBoard.detail && detail.contractBoard.action == .back)
    try #require(detail.contractBoard.quietChoirQuote?.action == .accept)
    return detail
  }
}

struct NativeQuietChoirOpeningUnitTests {
  @Test func bundledOpeningHasExactOriginalSourceAndNineObjectivesOnly() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledQuietChoirDirectory)
    try NativeQuietChoirDefinition.validateDeclaration(pack.manifest)
    #expect(NativeQuietChoirDefinition.matches(pack))
    #expect(pack.manifest.mission.title == "A Choir Beneath the Static")
    #expect(pack.manifest.mission.milestones == NativeC02OriginalStage.allCases.map(\.objective))
    #expect(pack.manifest.mission.milestones.count == 9)
    #expect(pack.manifest.handlers.count == 1 && pack.manifest.handlers.first?.event == "mission.accepted")
    #expect(pack.models.isEmpty && pack.resourceBytes.isEmpty && pack.manifest.npcs == nil)
    #expect(pack.manifest.equipment == nil && pack.manifest.encounters == nil && pack.manifest.trial == nil)
    #expect(NativeQuietChoirDefinition.issuer == .init(galaxy: 3, system: 40))
    #expect(NativeQuietChoirTravelHistory.minimumDistinctSystems == 4)
  }

  @Test func fourActualObservationsAndRealBerthStillRequireLarvaalIdentification() async throws {
    let fixture = try await QuietChoirOpeningFixture()
    defer { fixture.clean() }
    var game = try await fixture.review()
    let quote = try #require(game.contractBoard.quietChoirQuote)
    let observations = try #require(quote.observations)
    #expect(observations.count == 4 && Set(observations.map { $0.station.system }).count == 4)
    #expect(quote.identification == nil && !quote.allowed)
    #expect(quote.arrival != nil && quote.issues.contains { $0.contains("real Larvaal") })
    #expect(!quote.issues.contains { $0.contains("Four distinct") })
    #expect(game.quietChoirMission == nil && game.commander.scriptState.firstNativeCommodityTrade == nil)
    let before = game.commander
    let bytes = try Data(contentsOf: fixture.files.save)
    game.contractBoard.action = .accept
    #expect(throws: MissionPackError.self) { try game.confirmQuietChoir(quote) }
    #expect(game.commander == before && game.quietChoirMission == nil)
    await fixture.runtime.key("right")
    await fixture.runtime.key("return")
    #expect(await fixture.runtime.snapshot().commander == before)
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
    await fixture.runtime.key("escape")
    #expect(await fixture.runtime.snapshot().commander == before)
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
  }

  @Test func repeatedNativeRevisitsCannotReplaceFourDistinctSystems() async throws {
    let fixture = try await QuietChoirOpeningFixture(priorSystems: 5, repeatOneSystem: true)
    defer { fixture.clean() }
    let game = try await fixture.review()
    let quote = try #require(game.contractBoard.quietChoirQuote)
    let history = try game.quietChoirHistoryReview()
    #expect(history.distinctSystems < 4)
    #expect(game.commander.flightSimulation.visit > 4)
    #expect(quote.observations == nil && quote.identification == nil && !quote.allowed)
    #expect(quote.issues.contains { $0.contains("Four distinct") })
    #expect(quote.issues.contains { $0.contains("real Larvaal") })
    #expect(game.quietChoirMission == nil && NativeQuietChoirSave.validateClaims(game.commander))
  }

  @Test func currentColdSaveWithoutCommissionDoesNotInventIdentificationOrProgress() async throws {
    let fixture = try await QuietChoirOpeningFixture()
    defer { fixture.clean() }
    let before = await fixture.runtime.snapshot()
    let bytes = try Data(contentsOf: fixture.files.save)
    let cold = try ScriptSaveStore.read(bytes, from: fixture.files.save).0
    #expect(cold.scriptState.instances.values.allSatisfy { !NativeQuietChoirDefinition.marked($0) })
    #expect(cold.scriptState.savedFleetDiscovery == before.commander.scriptState.savedFleetDiscovery)
    #expect(NativeQuietChoirSave.validateClaims(cold))
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    #expect(loaded.nativeStationRuntimeEpoch != before.nativeStationRuntimeEpoch)
    #expect(loaded.quietChoirMission == nil && !loaded.quietChoirReview(.accept).allowed)
    #expect(NativeQuietChoirTravelHistory.identification(in: loaded) == nil)
    #expect(loaded.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(loaded.commander.credits == before.commander.credits && loaded.commander.cargo == before.commander.cargo)
    #expect(loaded.commander.nativePeople == before.commander.nativePeople)
    #expect(loaded.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
  }

  @Test func genericAcceptanceAndCommandsCannotCreateOriginalCaseOrFieldEvidence() async throws {
    let fixture = try await QuietChoirOpeningFixture()
    defer { fixture.clean() }
    var game = await fixture.runtime.snapshot()
    let pack = try #require(game.quietChoirPack)
    let before = game.commander
    #expect(throws: (any Error).self) { _ = try game.acceptScriptMission(pack) }
    #expect(game.commander == before && game.quietChoirMission == nil)
    // A negative, unaccepted marker has no acceptance facts or receipt. It is never saved.
    let empty = ScriptInstance(id: UUID(), definition: NativeQuietChoirDefinition.stateID,
      version: NativeQuietChoirDefinition.version, digest: pack.digest)
    let event = ScriptEvent(sequence: 1, kind: "mission.accepted", instance: empty.id, values: [:])
    let commands: [ScriptValue] = [
      .object(["op": .string("mission.finish"), "outcome": .string("complete")]),
      .object(["op": .string("milestone.ensure"), "index": .integer(1)]),
      .object(["op": .string("credits"), "id": .string("false-fee"), "amount": .integer(64000)]),
      .object(["op": .string("payload.add"), "id": .string("false-collector"), "key": .string("phase-collector"), "amount": .integer(1)]),
      .object(["op": .string("journal.append"), "text": .string(NativeQuietChoirDefinition.briefing[0])]),
    ]
    for command in commands {
      let fields = try #require(command.object)
      #expect(throws: MissionPackError.self) {
        try game.validateQuietChoirScriptCommand(fields, event: event, pack: pack,
          state: empty, candidate: game.commander)
      }
      var selected = empty
      var candidate = game.commander
      #expect(throws: (any Error).self) {
        try game.applyScriptCommand(command, event: event, pack: pack,
          state: &selected, candidate: &candidate)
      }
      #expect(selected == empty && candidate == before)
    }
  }

  @Test func currentRawReaderRefusesOrphanNullMisplacedDuplicateAndIncompleteClaims() throws {
    let id = UUID().uuidString
    let metadata = "\"definition\":\"\(NativeQuietChoirDefinition.stateID)\",\"digest\":\"\(NativeQuietChoirDefinition.digest)\""
    let invalid: [(String, ScriptFreightVersionedSave.Part)] = [
      ("{\"savedQuietChoir\":null}", .missions),
      ("{\"quietChoir\":{}}", .missions),
      ("{\"unexpected\":{\"savedQuietChoir\":{}}}", .missions),
      ("{\"instances\":{\"foreign\":{\"data\":{\"savedQuietChoir\":{}}}}}", .missions),
      ("{\"instances\":{\"\(id)\":{\(metadata)}}}", .missions),
      ("{\"instances\":{\"\(id)\":{\(metadata),\"savedQuietChoir\":null}}}", .missions),
      ("{\"instances\":{\"\(id)\":{\(metadata),\"savedQuietChoir\":{}}}}", .missions),
      ("{\"instances\":{\"\(id)\":{\(metadata),\"savedQuietChoir\":{},\"savedQuietChoir\":{}}}}", .missions),
      ("{\"savedScriptState\":{\"instances\":{\"\(id)\":{\(metadata),\"savedQuietChoir\":{}}}}}", .commander),
      ("{\"instances\":{\"\(id)\":{\(metadata),\"savedQuietChoir\":{}}}}", .contracts),
    ]
    for (raw, part) in invalid {
      #expect(throws: (any Error).self) {
        try NativeQuietChoirSave.validateFields(Data(raw.utf8), part: part)
      }
    }
    let parts: [ScriptFreightVersionedSave.Part] = [.missions, .commander, .contracts]
    for part in parts {
      try NativeQuietChoirSave.validateFields(Data("{}".utf8), part: part)
    }
  }

  @Test func galleryExplainsEligibilityAndDoesNotAwardAnyOfNineStages() async throws {
    let fixture = try await QuietChoirOpeningFixture()
    defer { fixture.clean() }
    let game = try await fixture.review()
    let before = game.commander
    let pack = try #require(game.quietChoirPack)
    let entry = try #require(game.quietChoirGalleryEntry(pack))
    #expect(entry.status == .locked && entry.completed == 0 && entry.trialDigest == nil)
    #expect(entry.milestones.count == 9 && entry.milestones.first?.state == "Current")
    #expect(entry.milestones.dropFirst().allSatisfy { $0.state == "Unavailable" })
    #expect(entry.prerequisites.contains { $0.contains("real Larvaal") })
    #expect(game.scriptGallery.filter { $0.name == "A Choir Beneath the Static" }.count == 1)
    #expect(game.quietChoirGalleryEntry(fixture.files.pack) == nil)
    let detail = game.quietChoirDetail().joined(separator: "\n")
    #expect(detail.contains("No trade, combat score, Glass Meridian completion or other paid campaign"))
    #expect(detail.contains("Acceptance requires no free hold or currently fitted scanner"))
    #expect(detail.contains("each require one tonne"))
    #expect(game.commander == before && game.quietChoirMission == nil)
  }
}
