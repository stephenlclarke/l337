import Foundation
import Testing

@testable import L337Core

struct ClassicExampleHullAvailabilityUnitTests {
  @Test func currentExampleCohortsKeepTheirExactRolesAndReceiptDependencies() throws {
    let maintenance = try pack("station-maintenance")
    let branch = try pack("branch-patrol")
    let patrol = try pack("scripted-patrol")
    let support = try #require(maintenance.manifest.encounters?.first)
    try #require(support.actors.map(\.id) == ["support-viper", "support-cobra"])
    #expect(support.actors[0].hull == .viper && support.actors[1].hull == .cobra)
    #expect(support.actors.map(\.x) == [0, 1000])
    #expect(support.actors.map(\.y) == [500, 500])
    #expect(support.actors.map(\.z) == [3000, 4500])
    #expect(support.galaxy == 0 && support.system == 7)
    #expect(support.actors.allSatisfy { !$0.hostile && $0.npc == nil })
    #expect(maintenance.manifest.worldJobs?.first?.controlledEncounters == [support.id])
    let kite = try #require(ShipCatalogue.nativeShip(.viper))
    #expect(kite.id == "SH031" && kite.name == "Kite Interceptor")
    #expect(ShipCatalogue.nativeMesh(.viper) != nil)
    #expect(ShipCatalogue.nativeShip(.cobra) == nil)
    #expect(ShipCatalogue.nativeShip(.sidewinder) == nil)
    #expect(OriginalDetailedHullStage.blocksRuntime("SH023"))
    #expect(OriginalDetailedHullStage.blocksRuntime("SH107"))

    for example in [branch, patrol] {
      let encounter = try #require(example.manifest.encounters?.first)
      #expect(encounter.actors.map(\.id) == ["lead", "wing"])
      #expect(encounter.actors.allSatisfy { $0.x == 0 && $0.y == 0 })
      #expect(encounter.actors.map(\.z) == [3000, 4500])
      #expect(encounter.galaxy == 0 && encounter.system == 7)
      #expect(encounter.actors.allSatisfy { $0.hull == .sidewinder && $0.hostile })
      #expect(example.manifest.mission.requiredDestructionEncounters == [encounter.id])
    }
    let choice = try pack("branch-choice")
    let courier = try pack("branch-courier")
    for (child, assignment) in [(branch, "patrol"), (courier, "courier")] {
      let requirement = try #require(child.manifest.receiptRequirements?.first)
      #expect(requirement.definition == choice.manifest.stateID)
      #expect(requirement.digest == choice.digest)
      #expect(requirement.choiceGroup == "assignment" && requirement.choice == assignment)
    }
    for name in ["linked-patrol", "scoped-patrol"] {
      let consumer = try pack(name)
      let requirements = (consumer.manifest.receiptRequirements ?? []).filter {
        $0.definition == patrol.manifest.stateID
      }
      try #require(!requirements.isEmpty)
      #expect(requirements.allSatisfy { $0.digest == patrol.digest })
    }
  }

  @Test func distributableScriptedPatrolRefusesWithoutPublishingEitherRaider() throws {
    let patrol = try pack("scripted-patrol")
    var game = try launchedExample(patrol)
    let instance = try #require(game.commander.scriptState.instances.values.first)
    try #require(instance.suspension == nil)
    game.emitScriptEvent("station.undocked", only: instance.id, drain: false)
    let before = game.commander
    let bodies = game.bodies
    let nextBodyID = game.nextBodyID
    let random = game.scriptSimulationSave.randomState
    game.drainScriptEvents()
    let owner = try #require(game.commander.scriptState.instances[instance.id])
    let reason = try #require(owner.suspension)
    #expect(reason.contains("Classic hull sidewinder has no exact mission geometry"))
    var expected = before
    expected.scriptState.instances[instance.id]?.suspension = reason
    #expect(game.commander == expected)
    #expect(game.bodies == bodies && game.nextBodyID == nextBodyID)
    #expect(game.scriptSimulationSave.randomState == random)
    #expect(owner.ownedEncounters.isEmpty && owner.completionReceipt == nil)
  }

  @Test func stationServiceCannotPublishTheKiteAloneWhenItsPartnerIsUnavailable() throws {
    let maintenance = try pack("station-maintenance")
    var game = try launchedExample(maintenance)
    let origin = try #require(game.commander.scriptState.instances.values.first)
    let job = try #require(game.commander.scriptState.worldJobs.values.first)
    try #require(origin.outcome == .complete && job.status == .active && job.suspension == nil)
    let bodies = game.bodies
    let nextBodyID = game.nextBodyID
    let flight = game.commander.flightSimulation
    let credits = game.commander.credits
    let kills = game.commander.kills
    for _ in 0..<35 {
      game.advanceScriptWorldJobs(delta: 0.1)
    }
    let refused = try #require(game.commander.scriptState.worldJobs[job.identity])
    let reason = try #require(refused.suspension)
    #expect(reason.contains("Classic hull cobra has no exact mission geometry"))
    #expect(refused.status == .active && refused.pending?.counters["opening"] == 3)
    #expect(refused.journal.isEmpty && origin.ownedEncounters.isEmpty)
    #expect(game.commander.scriptState.instances[origin.id] == origin)
    #expect(game.bodies == bodies && game.nextBodyID == nextBodyID)
    #expect(game.commander.flightSimulation == flight)
    #expect(game.commander.credits == credits && game.commander.kills == kills)
  }

  private func pack(_ name: String) throws -> ScriptPack {
    let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs")
    return try ScriptPackLibrary.read(examples.appendingPathComponent(name))
  }

  private func launchedExample(_ pack: ScriptPack) throws -> Game {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.screen = .status
    game.scriptPacks = [pack]
    _ = try game.acceptScriptMission(pack)
    game.launch()
    try #require(!game.docked)
    return game
  }
}
