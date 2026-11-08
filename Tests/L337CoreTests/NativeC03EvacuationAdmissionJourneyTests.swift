import Foundation
import Testing

@testable import L337Core

/// Original producers through register recovery are required. The final remote scene is
/// controlled, not earned travel. No source, fitting, person or native permission is injected.
/// These positive assertions stay mandatory while actual hull/loaded-fit adoption is pending.
struct NativeC03EvacuationAdmissionJourneyTests {
  @Test func actualOuterRuntimeIssuesTheOriginalPairAndColdSaveRetainsTheSameSixPeople()
    async throws
  {
    let actual = try await actualHollowEvacuationContextGame()
    defer { actual.commission.clean() }
    let before = actual.game.commander
    let runtime = GameRuntime(game: actual.game, saveURL: actual.commission.files.save)
    _ = await runtime.advance(delta: 0.05)
    let admitted = await runtime.snapshot()
    try #require(!admitted.paused && !admitted.docked)
    try #require(admitted.gameplayRevision == actual.game.gameplayRevision + 1)
    let custody = try #require(admitted.commander.nativePeople)
    let source = try #require(custody.hollowManifestCrew)
    let mission = try #require(admitted.hollowManifestMission)
    let state = try #require(mission.savedHollowManifest)
    let encounter = try #require(mission.ownedEncounters[NativeC03CrewSourceState.encounter])
    try #require(NativeC03CrewSourceSave.validSource(
      source, custody: custody, commander: admitted.commander))
    #expect(state.crewSource == source.missionReference)
    #expect(source.references.count == 6 && Set(source.references).count == 6)
    let originalFit = try NativeC03EvacuationAccommodation.candidate(
      owner: source.owner, mission: mission.id)
    #expect(source.registration.accommodation == originalFit)
    #expect(source.operatingPlaces.count == 2)
    #expect(source.hardware.ownedCabins.count == 1 && source.hardware.ownedBerths.count == 4)
    #expect(source.hardware.ownedBerths.allSatisfy {
      if case .nativePerson(let person) = $0.use { return person.hollowManifestCrew != nil }
      return false
    })
    #expect(source.nativeBindings.map(\.launch) == [false, true])
    #expect(source.nativeBindings.allSatisfy { $0.generation == 1 && $0.cohortCount == 2 })
    #expect(source.nativeBindings.map(\.selectedOrdinal) == [0, 1])
    #expect(encounter.admitted && encounter.actors.count == 2)
    for actor in encounter.actors.values {
      let body = try #require(admitted.bodies.first { $0.missionActorID == actor.identity })
      #expect(body.id == actor.body.id && body.physical?.identity == actor.body.physical?.identity)
      #expect(body.physical?.spawnIdentity == actor.body.physical?.spawnIdentity)
      #expect(actor.presence == .present)
    }
    #expect(admitted.commander.credits == before.credits)
    #expect(admitted.commander.cargo == before.cargo)
    #expect(admitted.commander.equipmentInventory == before.equipmentInventory)
    #expect(admitted.commander.accommodation == before.accommodation)
    #expect(mission.milestones == [0, 1, 2, 3, 4])
    #expect(source.crewLogHolder == .originalLaunch && source.crewLogAccess == nil && source.loss == nil)
    try await runtime.save(to: actual.commission.files.save)
    let saved = await runtime.snapshot()
    let retained = try #require(saved.commander.nativePeople?.hollowManifestCrew)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: actual.commission.files.save, persistMigrations: false)
    let reopened = await cold.snapshot()
    let restored = try #require(reopened.commander.nativePeople?.hollowManifestCrew)
    #expect(restored == retained)
    #expect(reopened.hollowManifestMission?.savedHollowManifest == saved.hollowManifestMission?.savedHollowManifest)
    #expect(restored.registration == source.registration && restored.references == source.references)
    _ = await cold.advance(delta: 0.05)
    let continued = await cold.snapshot()
    let sameOriginals = try #require(continued.commander.nativePeople?.hollowManifestCrew)
    #expect(sameOriginals.registration == source.registration)
    #expect(sameOriginals.references == source.references)
    #expect(sameOriginals.hardware == source.hardware)
    #expect(sameOriginals.operatingPlaces == source.operatingPlaces)
    #expect(continued.commander.nativePeople?.transfers == custody.transfers)
  }

  @Test func refusingAStaleContextOrIncompletePairPublishesNoSourceOrAllocators() async throws {
    let actual = try await actualHollowEvacuationContextGame()
    defer { actual.commission.clean() }
    let game = actual.game
    let context = try #require(try game.hollowManifestEvacuationAdmissionContext())
    let before = game.commander
    let bodies = game.bodies
    let nextBody = game.nextBodyID
    #expect(throws: (any Error).self) {
      _ = try game.prepareC03EvacuationCrewSource(
        context: context, admitted: [], flight: game.commander.flightSimulation)
    }
    var changed = game
    changed.commander.flightSimulation.physicalTime += 0.05
    let changedBefore = changed.commander
    #expect(throws: NativeMissionActorAdmissionError.stalePlan) {
      _ = try changed.prepareC03EvacuationCrewSource(
        context: context, admitted: [], flight: changed.commander.flightSimulation)
    }
    #expect(changed.commander == changedBefore && changed.bodies == bodies && changed.nextBodyID == nextBody)
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == nextBody)
    #expect(game.commander.nativePeople?.hollowManifestCrew == nil)
  }

  @Test func pausedOuterRuntimeCannotIssueTheOriginalPairOrAdvanceMissionHistory() async throws {
    let actual = try await actualHollowEvacuationContextGame()
    defer { actual.commission.clean() }
    var paused = actual.game
    paused.paused = true
    let runtime = GameRuntime(game: paused, saveURL: actual.commission.files.save)
    let before = await runtime.snapshot()
    _ = await runtime.advance(delta: 0.05)
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander)
    #expect(after.bodies == before.bodies && after.nextBodyID == before.nextBodyID)
    #expect(after.commander.nativePeople?.hollowManifestCrew == nil)
    #expect(after.hollowManifestMission?.milestones == [0, 1, 2, 3, 4])
  }
}
