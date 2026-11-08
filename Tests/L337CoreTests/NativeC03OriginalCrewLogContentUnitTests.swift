import Foundation
import Testing

@testable import L337Core

private func realHollowCaseAfterRegisterForLogContent() async throws -> (
  game: Game, commission: HollowManifestCommissionFixture
) {
  let (runtime, commission) = try await actualHollowRegisterRuntime()
  do {
    let selected = try await selectActualHollowRegister(runtime)
    await runtime.missionUICommand(.init(action: .originalRegisterRecovery,
      game: selected, presentation: selected.scriptPagePresentation))
    let game = await runtime.snapshot()
    _ = try game.hollowManifestHeldRegisterData()
    return (game, commission)
  } catch {
    commission.clean()
    throw error
  }
}

/// Negative real-prerequisite tests only. Actual care/ward/provider/arrival/access
/// fixtures must come from those genuine producers before a positive handoff is tested.
struct NativeC03CrewLogAccessUnitTests {
  @Test func actualFreshOwnerCannotReadAnUnissuedOriginalCrewLog() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let commander = game.commander
    let bodies = game.bodies
    #expect(throws: SaveError.invalidCommander) { try game.hollowManifestHeldCrewLog() }
    #expect(game.commander == commander && game.bodies == bodies)
  }

  @Test func actualRecoveredRegisterAndOriginalKitCannotStandInForRescuedCrewLogAccess() async throws {
    let actual = try await realHollowCaseAfterRegisterForLogContent()
    defer { actual.commission.clean() }
    let game = actual.game
    let original = try game.hollowManifestHeldRegisterData()
    let commander = game.commander
    let bodies = game.bodies
    #expect(throws: SaveError.invalidCommander) { try game.hollowManifestHeldCrewLog() }
    let retained = try game.hollowManifestHeldRegisterData()
    #expect(retained.kit == original.kit && retained.contents == original.contents)
    #expect(retained.transfer == original.transfer)
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.commander.nativePeople?.hollowManifestCrew == nil)
  }
}

/// The preceding case/data producers are real; the generated document is only candidate
/// content. No physical log, crew source, accepted care or case completion is fabricated.
struct NativeC03OriginalCrewLogContentUnitTests {
  @Test func candidateLogCorroboratesActualRegisterAndRetainsOriginalHullAndSealAddresses() async throws {
    let actual = try await realHollowCaseAfterRegisterForLogContent()
    defer { actual.commission.clean() }
    let game = actual.game
    let state = try #require(game.hollowManifestMission?.savedHollowManifest)
    let fit = try NativeC03EvacuationAccommodation.candidate(
      owner: state.birth.input.owner, mission: state.birth.input.mission)
    let commander = game.commander
    let register = try game.hollowManifestHeldRegisterData()
    let log = try NativeC03OriginalCrewLogContent.candidate(state: state, fit: fit)
    #expect(log.valid(in: state, fit: fit) && log.shapeValid(fit: fit))
    #expect(log.seals == register.contents.seals && log.master == register.contents.master)
    #expect(log.recordedCargo == .sealedRefineryWaste && log.insuranceDeclaration == .machinery)
    #expect(!log.crewWereToldContents && log.serviceCompartmentOverheatReported)
    #expect(log.carrier == fit.originalCarrier && log.launch == fit.originalLaunch)
    #expect(game.commander == commander && game.commander.nativePeople?.hollowManifestCrew == nil)
    #expect(state.crewSource == nil)
  }

  @Test func changedDocumentClaimsOrSealAddressesCannotBeTheUnalteredOriginalLog() async throws {
    let actual = try await realHollowCaseAfterRegisterForLogContent()
    defer { actual.commission.clean() }
    let state = try #require(actual.game.hollowManifestMission?.savedHollowManifest)
    let fit = try NativeC03EvacuationAccommodation.candidate(
      owner: state.birth.input.owner, mission: state.birth.input.mission)
    let log = try NativeC03OriginalCrewLogContent.candidate(state: state, fit: fit)
    let raw = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(log)) as? [String: Any])
    for field in ["serial", "carrier", "launch", "master"] {
      var changed = raw
      changed[field] = UUID().uuidString
      let decoded = try JSONDecoder().decode(NativeC03OriginalCrewLogContent.self,
        from: JSONSerialization.data(withJSONObject: changed))
      #expect(!decoded.valid(in: state, fit: fit))
    }
    var changed = raw
    changed["recordedCargo"] = "machinery"
    let decoded = try JSONDecoder().decode(NativeC03OriginalCrewLogContent.self,
      from: JSONSerialization.data(withJSONObject: changed))
    #expect(!decoded.valid(in: state, fit: fit))
    changed = raw
    var seals = try #require(changed["seals"] as? [[String: Any]])
    seals[0]["imprint"] = UUID().uuidString
    changed["seals"] = seals
    let changedSeal = try JSONDecoder().decode(NativeC03OriginalCrewLogContent.self,
      from: JSONSerialization.data(withJSONObject: changed))
    #expect(!changedSeal.valid(in: state, fit: fit))
    #expect(actual.game.commander.nativePeople?.hollowManifestCrew == nil)
  }
}
