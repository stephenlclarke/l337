import Foundation
import Testing

@testable import L337Core

/// Every positive uses the existing real two-seal/lab/three-wake/archive producers.
/// Their controlled remote scene and labelled test funding are not earned travel/wealth.
/// No original register, kit, observation, source, permission or transfer is injected. UNRUN.
struct NativeC03RecoveredArchiveReaderUnitTests {
  private func recover(_ runtime: GameRuntime) async throws -> Game {
    let selected = try await selectActualHollowRegister(runtime)
    try #require(selected.hollowManifestRegisterTarget != nil)
    await runtime.missionUICommand(.init(action: .originalRegisterRecovery,
      game: selected, presentation: selected.scriptPagePresentation))
    let recovered = await runtime.snapshot()
    _ = try #require(recovered.hollowManifestMission?.savedHollowManifest?.custodyRegister?.recovery)
    return recovered
  }

  @Test func actualRecoveredPagesExposeClaimsAndOriginalReferencesWithoutProgressOrWrites() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let before = await runtime.snapshot()
    #expect(throws: (any Error).self) { try before.hollowManifestRecoveredArchiveReader() }
    let recovered = try await recover(runtime)
    let held = try recovered.hollowManifestHeldRegisterData()
    let state = try #require(recovered.hollowManifestMission?.savedHollowManifest)
    let laboratory = try #require(state.laboratory)
    let files = try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent())
    let commander = recovered.commander
    var reader = try recovered.hollowManifestRecoveredArchiveReader()
    let declarations = try reader.page(in: recovered)
    #expect(declarations.section == .declarations && declarations.register == held.contents.serial)
    #expect(declarations.transfer == held.transfer)
    #expect(declarations.rows.prefix(2).map(\.value) == ["Sealed refinery waste", "Machinery"])
    #expect(declarations.rows.prefix(2).allSatisfy { $0.basis == .documentClaim })
    #expect(declarations.rows.last?.basis == .recordedComparison)
    #expect(declarations.rows.last?.reference == held.comparison.operation)
    for (index, section) in [NativeC03RecoveredArchiveReader.Section.firstSeal, .secondSeal].enumerated() {
      let page = try reader.select(section, in: recovered)
      let inspection = try #require(page.rows.first { $0.label == "Laboratory inspection" })
      #expect(inspection.basis == .observedSealReference)
      #expect(inspection.reference == laboratory.facts.analysis.facts.observations[index].inspection)
      #expect(page.rows.first?.reference == held.contents.seals[index].seal)
      #expect(page.notice.contains("does not prove physical cargo"))
    }
    let wakes = try reader.select(.wakeReferences, in: recovered)
    #expect(wakes.rows.compactMap(\.reference) == held.contents.wakeObservations)
    #expect(wakes.rows.count == 3 && wakes.rows.allSatisfy { $0.basis == .recordedWakeReference })
    let crew = try reader.select(.crewNotice, in: recovered)
    #expect(crew.rows.first?.basis == .documentClaim)
    #expect(crew.rows.first?.value.contains("claims the crew were not told") == true)
    #expect(crew.rows.last?.basis == .requirement && crew.rows.last?.reference == nil)
    #expect(crew.rows.last?.value.contains("unaltered log") == true)
    #expect(recovered.commander == commander)
    #expect(recovered.hollowManifestMission?.milestones == [0, 1, 2, 3, 4])
    #expect(state.caseFile == nil && recovered.hollowManifestMission?.completionReceipt == nil)
    #expect(try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent()) == files)
    let value: Any = reader
    #expect(!(value is any Encodable))
  }

  @Test func validatedCursorNavigationClampsBothEndsAndKeepsTheSameRecoveredOriginal() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let recovered = try await recover(runtime)
    let held = try recovered.hollowManifestHeldRegisterData()
    var reader = try recovered.hollowManifestRecoveredArchiveReader()
    let first = try reader.move(.previous, in: recovered)
    #expect(first.section == .declarations && reader.section == .declarations)
    for section in NativeC03RecoveredArchiveReader.Section.allCases.dropFirst() {
      let page = try reader.move(.next, in: recovered)
      #expect(page.section == section && reader.section == section)
      #expect(page.register == held.contents.serial && page.transfer == held.transfer)
    }
    let last = try reader.move(.next, in: recovered)
    #expect(last.section == .crewNotice && reader.section == .crewNotice)
    for section in NativeC03RecoveredArchiveReader.Section.allCases.dropLast().reversed() {
      let page = try reader.move(.previous, in: recovered)
      #expect(page.section == section && reader.section == section)
    }
    #expect(recovered.hollowManifestMission?.milestones == [0, 1, 2, 3, 4])
    #expect(recovered.hollowManifestMission?.savedHollowManifest?.custodyRegister?.sourceContents == nil)
  }

  @Test func currentColdLoadRetainsTheSoleOriginalButInvalidatesItsLiveReader() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let recovered = try await recover(runtime)
    let held = try recovered.hollowManifestHeldRegisterData()
    var reader = try recovered.hollowManifestRecoveredArchiveReader()
    let page = try reader.select(.wakeReferences, in: recovered)
    try await runtime.save(to: commission.files.save)
    var shell = Game(executive: false)
    shell.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledHollowManifestDirectory)]
    let cold = GameRuntime(game: shell, saveURL: commission.files.save)
    try await cold.load(from: commission.files.save, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(loaded.nativeStationRuntimeEpoch != recovered.nativeStationRuntimeEpoch)
    #expect(throws: NativeC03RecoveredArchiveReader.ReaderError.self) { try reader.page(in: loaded) }
    var refused = false
    do { _ = try reader.select(.crewNotice, in: loaded) }
    catch { refused = true }  // Expected stale runtime context, not a completed read.
    #expect(refused && reader.section == .wakeReferences)
    var fresh = try loaded.hollowManifestRecoveredArchiveReader()
    #expect(fresh.section == .declarations)
    let reopened = try fresh.select(.wakeReferences, in: loaded)
    #expect(reopened == page)
    let retained = try loaded.hollowManifestHeldRegisterData()
    #expect(retained.transfer == held.transfer && retained.contents == held.contents)
    #expect(retained.kit.serial == held.kit.serial)
    let record = try #require(loaded.hollowManifestMission?.savedHollowManifest?.custodyRegister)
    #expect(record.sourceContents == nil && record.holder == .originalInspectionKit(held.kit.serial))
    #expect(loaded.hollowManifestMission?.milestones == [0, 1, 2, 3, 4])
    #expect(loaded.hollowManifestMission?.completionReceipt == nil)
  }

  @Test func missingKitTrialEpochAndCaseChangesRefuseWithoutMovingTheCursor() async throws {
    let (runtime, commission) = try await actualHollowRegisterRuntime()
    defer { commission.clean() }
    let recovered = try await recover(runtime)
    let held = try recovered.hollowManifestHeldRegisterData()
    var reader = try recovered.hollowManifestRecoveredArchiveReader()
    _ = try reader.select(.secondSeal, in: recovered)
    // Corrupted negative value copies only; none is an actual loss, transfer or trial.
    var missing = recovered
    let inventory = try #require(missing.commander.equipmentInventory)
    missing.commander.savedEquipmentInventory = try .init(owner: inventory.owner,
      activeHull: inventory.activeHull, revision: inventory.revision + 1,
      items: inventory.items.filter { $0.id != held.kit.serial })
    var trial = recovered
    trial.isMissionTrial = true
    var epoch = recovered
    epoch.nativeStationRuntimeEpoch = UUID()
    var revision = recovered
    let mission = try #require(revision.hollowManifestMission?.id)
    revision.commander.scriptState.instances[mission]?.revision += 1
    for invalid in [missing, trial, epoch, revision] {
      #expect(throws: (any Error).self) { try reader.page(in: invalid) }
      var refused = false
      do { _ = try reader.move(.next, in: invalid) }
      catch { refused = true }  // Each actual read must revalidate current source/custody.
      #expect(refused && reader.section == .secondSeal)
    }
    let valid = try reader.page(in: recovered)
    #expect(valid.section == .secondSeal && valid.register == held.contents.serial)
    #expect(recovered.hollowManifestMission?.savedHollowManifest?.caseFile == nil)
    #expect(recovered.hollowManifestMission?.completionReceipt == nil)
  }
}
