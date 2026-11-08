import Foundation
import Testing

@testable import L337Core

/// Producer-backed contact tests. Remote scene/cargo setup is controlled test data, not an
/// earned route. Bootstrap, swept berth entry, sale, Confirm and save writer must really run.
struct NativeHollowManifestCommissionUnitTests {
  @Test func actualConfirmRetainsOneCurrentBirthWithoutChargingOrIssuingTheKit() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    let preview = try await fixture.review()
    let bytes = try Data(contentsOf: fixture.files.save)
    try #require(preview.hollowManifestMission == nil)
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let instance = try #require(accepted.hollowManifestMission)
    let state = try #require(instance.savedHollowManifest)
    #expect(state.phase == .unadmitted && state.admissions.isEmpty)
    #expect(state.birth.operations.map(\.sequence) == Array(UInt64(1)...7))
    #expect(state.birth.originals.count == 2 && state.nextSourceSequence == 8)
    #expect(state.birth.fit.hullEnergy == 220 && state.birth.fit.recharge == 3.1)
    #expect(state.birth.fit.maximumSpeed == 39)
    #expect(instance.milestones == [0] && instance.receipts == [NativeHollowManifestCommission.receipt])
    #expect(instance.gearIssues.isEmpty && instance.ownedEncounters.isEmpty)
    #expect(state.inspections.isEmpty && state.laboratory == nil)
    #expect(state.crewSource == nil && state.caseFile == nil)
    #expect(accepted.commander.credits == preview.commander.credits)
    #expect(accepted.commander.equipmentInventory == preview.commander.equipmentInventory)
    #expect(accepted.commander.cargo == preview.commander.cargo)
    #expect(try Data(contentsOf: fixture.files.save) != bytes)
    let restored = try ScriptSaveStore.read(
      Data(contentsOf: fixture.files.save), from: fixture.files.save).0
    #expect(restored.scriptState.instances[instance.id]?.savedHollowManifest == state)
    #expect(NativeHollowManifestSave.validateClaims(restored))
  }

  @Test func actualBackAndWriterRefusalPreserveTheCaseAndPermitOneRealRetry() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    let preview = try await fixture.review()
    let bytes = try Data(contentsOf: fixture.files.save)
    await fixture.runtime.key("escape")
    let closed = await fixture.runtime.snapshot()
    #expect(closed.commander == preview.commander && closed.hollowManifestMission == nil)
    #expect(try Data(contentsOf: fixture.files.save) == bytes)
    _ = try await fixture.review()
    await fixture.selectConfirm()
    let chosen = await fixture.runtime.snapshot()
    let directory = fixture.files.save.deletingLastPathComponent()
    let backup = fixture.files.root.appendingPathComponent("before-commission-save")
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked commission writer".utf8).write(to: directory)
    await fixture.runtime.key("return")
    let refused = await fixture.runtime.snapshot()
    #expect(refused.commander == chosen.commander && refused.hollowManifestMission == nil)
    #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let instance = try #require(accepted.hollowManifestMission)
    #expect(instance.savedHollowManifest?.nextSourceSequence == 8)
    #expect(instance.receipts == [NativeHollowManifestCommission.receipt])
    #expect(accepted.commander.credits == chosen.commander.credits)
    let written = try Data(contentsOf: fixture.files.save)
    await fixture.runtime.key("return")
    let repeated = await fixture.runtime.snapshot()
    #expect(repeated.hollowManifestMission?.id == instance.id)
    #expect(repeated.hollowManifestMission?.savedHollowManifest == instance.savedHollowManifest)
    #expect(try Data(contentsOf: fixture.files.save) == written)
  }

  @Test func genuineNativeAdmissionKeepsCurrentSourceAndOriginalAssignments() async throws {
    let (game, fixture) = try await actualHollowManifestFreighterRootFixture()
    defer { fixture.clean() }
    let pin = try game.hollowManifestInstalledCase()
    let source = try NativeHollowManifestFleetSource.resolve(.inspectionFreighter)
    try #require(pin.state.phase == .admitted && pin.state.latestAdmissions.count == 2)
    #expect(pin.state.birth.rootDesign == source.physical.model.nativeDesign)
    for slot in NativeHollowManifestState.Slot.allCases {
      let life = try game.hollowManifestOriginalLife(slot: slot)
      let admission = try #require(life.admission)
      let bound = try #require(game.c03CurrentOriginalBinding(pin, slot: slot))
      let body = try #require(game.bodies.first { $0.id == bound.owned.body.id })
      #expect(body.physical?.identity == admission.original.actor)
      #expect(body.physical?.spawnIdentity == admission.spawn)
      #expect(body.physical?.npc?.resources.energyCapacity == source.performance.energy)
      #expect(body.physical?.npc?.resources.energyRecharge == source.performance.recharge)
      #expect(life.original.operatingCrew == source.accommodation.operatingCrew)
      #expect(life.original.intrinsicCrewQuarters == source.accommodation.intrinsicCrewPlaces)
    }
  }
}
