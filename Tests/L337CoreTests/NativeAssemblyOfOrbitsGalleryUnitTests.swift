import Foundation
import Testing

@testable import L337Core

/// Reuses actual current native bootstrap/berth/trade/commission/issue producers.
/// Remote scene setup remains explicitly controlled, not a flown-route acceptance. UNRUN.
struct NativeAssemblyOfOrbitsGalleryUnitTests {
  private func entry(_ game: Game) throws -> GalleryMission {
    let pack = try #require(game.assemblyOfOrbitsPack)
    let owned = try #require(game.assemblyOfOrbitsGalleryEntry(pack))
    let visible = game.scriptGallery.filter { $0.name == "An Assembly of Orbits" }
    try #require(visible.count == 1)
    #expect(visible[0].status == owned.status && visible[0].objective == owned.objective)
    #expect(visible[0].completed == owned.completed && visible[0].savedInstance == owned.savedInstance)
    #expect(visible[0].trialDigest == nil && owned.trialDigest == nil)
    #expect(visible[0].milestones.map(\.title) == owned.milestones.map(\.title))
    #expect(visible[0].milestones.map(\.state) == owned.milestones.map(\.state))
    return owned
  }

  @Test func genuinePurchaseOpensOnlyCommissionAndGalleryInputRemainsReadOnly() async throws {
    let fixture = try await AssemblyOpeningFixture(buy: false)
    defer { fixture.clean() }
    let noTrade = await fixture.runtime.snapshot()
    let locked = try entry(noTrade)
    #expect(locked.status == .locked && locked.completed == 0 && locked.savedInstance == nil)
    #expect(locked.milestones.count == 9 && locked.milestones[0].state == "Upcoming")
    #expect(locked.milestones.dropFirst(2).allSatisfy { $0.state == "Unavailable" })
    try await AssemblyOpeningFixture.buyOne(fixture.runtime)
    let bought = await fixture.runtime.snapshot()
    let available = try entry(bought)
    #expect(available.status == .available && available.completed == 0)
    #expect(available.prerequisites.isEmpty && available.savedInstance == nil)
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    await fixture.runtime.nativeCommand { game in
      game.screen = .status
      game.openGallery()
      if let index = game.missionCatalogue.firstIndex(where: { $0.name == "An Assembly of Orbits" }) {
        game.gallery.selection = index
      }
    }
    let gallery = await fixture.runtime.snapshot()
    try #require(gallery.screen == .gallery && gallery.selectedGalleryMission?.name == available.name)
    #expect(!gallery.canTrialSelectedMission && !gallery.canRetrySelectedMission)
    await fixture.runtime.key("return")
    await fixture.runtime.key("t")
    await fixture.runtime.key("escape")
    await fixture.runtime.key("escape")
    let closed = await fixture.runtime.snapshot()
    #expect(closed.screen == .status && !closed.isMissionTrial)
    #expect(closed.commander == bought.commander && closed.assemblyOfOrbitsMission == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == files)
  }

  @Test func acceptanceAndOriginalLoanHaveSeparateHistoryWithoutQualifyingAnySurvey() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    let accepted = try await fixture.confirm(.accept)
    let first = try entry(accepted)
    #expect(first.status == .active && first.completed == 1)
    #expect(first.milestones[0].state == "Complete" && first.milestones[1].state == "Current")
    #expect(first.briefing.contains("Voss retains the original instrument"))
    #expect(first.destination == "Irkenan / Galaxy 7")
    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.assemblyOfOrbitsMission)
    let loan = try NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: collected.commander)
    let before = collected.commander
    let second = try entry(collected)
    #expect(second.status == .locked && second.completed == 2 && second.savedInstance == instance.id)
    #expect(second.milestones.prefix(2).allSatisfy { $0.state == "Complete" })
    #expect(second.milestones.dropFirst(2).allSatisfy { $0.state == "Unavailable" })
    #expect(second.destination == "Darik / Galaxy 7")
    #expect(second.briefing.contains("same original reference instrument is aboard"))
    #expect(second.briefing.contains("12 uninterrupted seconds"))
    #expect(second.objective.contains("not currently available"))
    #expect(second.trialDigest == nil && instance.outcome == .active)
    #expect(instance.completionReceipt == nil && instance.milestones == [0, 1])
    #expect(collected.commander == before)
    #expect(try NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: collected.commander) == loan)
    #expect(collected.commander.credits == accepted.commander.credits)
    #expect(collected.commander.scriptState.savedClueJournal == accepted.commander.scriptState.savedClueJournal)
  }

  @Test func currentColdLoadPreservesOnlyActualOpeningHistoryAndNoTrialAction() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let before = try entry(collected)
    try await fixture.runtime.save(to: fixture.files.save)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let restored = await fixture.runtime.snapshot()
    let after = try entry(restored)
    #expect(after.status == before.status && after.completed == 2 && after.savedInstance == before.savedInstance)
    #expect(after.objective == before.objective && after.destination == before.destination)
    #expect(after.milestones.map(\.title) == before.milestones.map(\.title))
    #expect(after.milestones.map(\.state) == before.milestones.map(\.state))
    #expect(after.trialDigest == nil && after.status != .complete)
    #expect(restored.assemblyOfOrbitsMission?.savedAssemblyOfOrbits == collected.assemblyOfOrbitsMission?.savedAssemblyOfOrbits)
    #expect(restored.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(restored.commander.scriptState.savedClueJournal == collected.commander.scriptState.savedClueJournal)
  }

  @Test func falseCountsMissingOriginalItemAndMissingPackNeverAdvertiseCompletion() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let instance = try #require(collected.assemblyOfOrbitsMission)
    let state = try #require(instance.savedAssemblyOfOrbits)
    let collection = try #require(state.collection)
    let pack = try #require(collected.assemblyOfOrbitsPack)
    for complete in [false, true] {
      var invalid = collected
      invalid.commander.scriptState.instances[instance.id]?.milestones = Set(0..<9)
      if complete { invalid.commander.scriptState.instances[instance.id]?.outcome = .complete }
      let before = invalid.commander
      let page = try #require(invalid.assemblyOfOrbitsGalleryEntry(pack))
      #expect(page.status == .locked && page.completed == 0 && page.trialDigest == nil)
      #expect(page.reward == "No settlement available." && invalid.commander == before)
    }
    var missingItem = collected
    if let inventory = missingItem.commander.savedEquipmentInventory {
      missingItem.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.filter { $0.id != collection.facts.original })
    }
    let missingPage = try #require(missingItem.assemblyOfOrbitsGalleryEntry(pack))
    #expect(missingPage.status == .locked && missingPage.completed == 0)
    #expect(missingItem.commander.scriptState.instances[instance.id]?.savedAssemblyOfOrbits == state)
    var missingPack = collected
    missingPack.scriptPacks = []
    let before = missingPack.commander
    let page = try #require(missingPack.assemblyOfOrbitsMissingGalleryEntry(instance))
    #expect(page.status == .locked && page.completed == 0 && page.trialDigest == nil)
    #expect(page.savedInstance == instance.id && page.objective.contains("history remain recorded"))
    let visible = missingPack.scriptGallery.filter { $0.savedInstance == instance.id }
    try #require(visible.count == 1)
    #expect(visible[0].status == .locked && visible[0].completed == 0)
    #expect(missingPack.commander == before)
    #expect(NativeAssemblyOfOrbitsSave.validateClaims(collected.commander))
  }
}
