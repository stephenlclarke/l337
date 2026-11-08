import Foundation
import Testing

@testable import L337Core

struct NativeC03AdmissionBorrowReadTests {
  @Test func genuineNativeLaunchKeepsAbsentLaterC03SourcesInert() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    let docked = await fixture.runtime.snapshot()
    try #require(docked.docked && docked.nativeMainStationDockEvidenceIsCurrent)
    try #require(docked.hollowManifestMission == nil)
    let owner = docked.commander.equipmentOwnerID
    let hull = docked.commander.hullInstanceID
    await fixture.runtime.nativeCommand { $0.screen = .status }
    // Use the actual launch/preflight/restoration owner that the new crash reaches.
    await fixture.runtime.key("0")
    let launched = await fixture.runtime.snapshot()
    try #require(!launched.docked && !launched.paused && launched.screen.isFlight,
      Comment(rawValue: launched.message))
    #expect(launched.commander.equipmentOwnerID == owner && launched.commander.hullInstanceID == hull)
    #expect(launched.hollowManifestMission == nil)
    let before = launched.commander
    let bodies = launched.bodies
    let file = try Data(contentsOf: fixture.files.save)
    #expect(try launched.hollowManifestWakeAdmissionContext() == nil)
    #expect(try launched.hollowManifestRegisterAdmissionContext() == nil)
    #expect(try launched.hollowManifestEvacuationAdmissionContext() == nil)
    _ = try launched.validateRetainedMissionActorRestoration()
    #expect(launched.commander == before && launched.bodies == bodies)
    #expect(try Data(contentsOf: fixture.files.save) == file)
  }

  @Test func genuineFreighterSourceAndCaseFreshnessSurviveTheWholeReadFamily() async throws {
    let (game, fixture) = try await actualHollowManifestFreighterRootFixture()
    defer { fixture.clean() }
    let before = game.commander
    let bodies = game.bodies
    let file = try Data(contentsOf: fixture.files.save)
    let pin = try game.hollowManifestInstalledCase()
    try #require(pin.state.phase == .admitted && pin.state.latestAdmissions.count == 2)
    try #require(game.acceptsHollowManifestInstalledCase(pin))
    let sources = try game.validateRetainedMissionActorRestoration()
    try #require(!sources.isEmpty)
    // Later contexts cannot borrow freighter source/scene authority or issue actors.
    #expect(try game.hollowManifestWakeAdmissionContext() == nil)
    #expect(try game.hollowManifestRegisterAdmissionContext() == nil)
    #expect(try game.hollowManifestEvacuationAdmissionContext() == nil)
    for slot in NativeHollowManifestState.Slot.allCases {
      let life = try game.hollowManifestOriginalLife(slot: slot)
      let admission = try #require(life.admission)
      let binding = try #require(game.c03CurrentOriginalBinding(pin, slot: slot))
      let body = try #require(game.bodies.first { $0.id == binding.owned.body.id })
      #expect(body.physical?.identity == admission.original.actor)
      #expect(body.physical?.spawnIdentity == admission.spawn)
      #expect(game.acceptsHollowManifestOriginalLife(life))
    }
    #expect(game.commander == before && game.bodies == bodies)
    #expect(try Data(contentsOf: fixture.files.save) == file)
    // A changed real event frontier must still invalidate the old immutable case pin.
    // This is an uncommitted negative input, never a replacement source or saved root.
    var changed = game
    try #require(changed.commander.scriptState.nextEvent < UInt64.max)
    changed.commander.scriptState.nextEvent += 1
    let changedBefore = changed.commander
    #expect(!changed.acceptsHollowManifestInstalledCase(pin))
    #expect(changed.commander == changedBefore && changed.bodies == bodies)
    #expect(game.commander == before && game.acceptsHollowManifestInstalledCase(pin))
    #expect(try Data(contentsOf: fixture.files.save) == file)
  }
}
