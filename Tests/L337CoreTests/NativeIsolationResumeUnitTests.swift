import Foundation
import Testing

@testable import L337Core

struct NativeIsolationResumeUnitTests {
  @Test func currentColdLoadPreservesPartialWorkAndRequiresFreshPhysicalArming() async throws {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    try fixture.arm()
    for _ in 0..<80 { try fixture.tick() }
    let partial = try fixture.state()
    try #require(partial.modules[0].history.seconds(.work) > 0)
    try #require(partial.modules[0].history.seconds(.work) < 20)
    try #require(partial.modules.allSatisfy {
      $0.accounts.valid && $0.accounts.remainingSupply > 0 && $0.opening == nil && $0.verification == nil
    })

    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: fixture.game)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    try await IsolationWorkFixture.arm(runtime)
    try await runtime.save(to: files.save)
    let saved = await runtime.snapshot()
    let child = try #require(saved.isolationWorkChild)
    let written = try #require(child.savedIsolationWork)
    let parent = try #require(saved.isolationWorkParentMission)
    let loan = try NativeIsolationProgrammerCustody.resolve(parent: parent, commander: saved.commander)
    let oldArm = try #require(saved.isolationWorkRuntime.arm)
    try #require(saved.isolationWorkEndpoint() != nil && written == partial)
    let pointerBytes = try Data(contentsOf: files.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    try #require(pointer.valueCodec == ScriptValueStorage.codec)
    let (stored, _) = try ScriptSaveStore.read(pointerBytes, from: files.save)
    #expect(stored.isolationInstance(child.id)?.savedIsolationWork == written)

    try await runtime.load(from: files.save, persistMigrations: false)
    let restored = await runtime.snapshot()
    let restoredChild = try #require(restored.isolationWorkChild)
    let restoredParent = try #require(restored.isolationWorkParentMission)
    #expect(restored.nativeStationRuntimeEpoch != saved.nativeStationRuntimeEpoch)
    #expect(restored.isolationWorkRuntime.contact == nil)
    #expect(restored.isolationWorkRuntime.review == nil && restored.isolationWorkRuntime.arm == nil)
    #expect(restored.isolationWorkEndpoint() == nil)
    #expect(restoredChild.id == child.id && restoredChild.savedIsolationWork == written)
    #expect(restoredParent.id == parent.id && restoredParent.outcome == .active)
    #expect(restoredParent.savedIsolationWorkParent == parent.savedIsolationWorkParent)
    #expect(restored.commander.equipmentInventory == saved.commander.equipmentInventory)
    #expect(restored.commander.credits == saved.commander.credits)
    #expect(restored.commander.cargo == saved.commander.cargo)
    #expect(try NativeIsolationProgrammerCustody.resolve(
      parent: restoredParent, commander: restored.commander) == loan)
    #expect(restored.commander.scriptState.instances.values.filter(NativeIsolationWorkPack.marked).count == 1)
    #expect(restored.commander.scriptState.instances.values.filter(NativeIsolationWorkParent.marked).count == 1)
    #expect(NativeIsolationWorkParentSave.validateClaims(restored.commander))
    #expect(NativeIsolationWorkSave.validateClaims(restored.commander))
    #expect(NativeIsolationContractSave.validateClaims(restored.commander))
    for role in NativeIsolationWorkRole.allCases {
      let actual = restored.bodies.filter {
        $0.missionInstanceID == child.id
          && $0.missionActorID == NativeIsolationWorkPack.actor(job: child.id, role: role)
      }
      try #require(actual.count == 1)
      #expect(restored.isolationWorkRole(actual[0]) == role)
    }

    // Replaying the actual old arm in discarded transient state cannot mint an endpoint.
    var replay = restored
    replay.isolationWorkRuntime.arm = oldArm
    #expect(replay.isolationWorkEndpoint() == nil)
    let replayUnchanged = replay.commander == restored.commander
    #expect(replayUnchanged)

    // Ordinary unarmed simulation still transfers finite power, but earns no work.
    let passive = await runtime.advance(delta: 0.05)
    let unarmed = try #require(passive.isolationWorkChild?.savedIsolationWork)
    try #require(unarmed.producerSequence > written.producerSequence)
    for index in written.modules.indices {
      #expect(unarmed.modules[index].history == written.modules[index].history)
      #expect(unarmed.modules[index].accounts.valid)
      #expect(unarmed.modules[index].accounts.deliveredLoad > written.modules[index].accounts.deliveredLoad)
      #expect(unarmed.modules[index].accounts.remainingSupply < written.modules[index].accounts.remainingSupply)
      #expect(unarmed.modules[index].admission == written.modules[index].admission)
      #expect(unarmed.modules[index].opening == nil && unarmed.modules[index].verification == nil)
    }
    #expect(passive.isolationWorkRuntime.arm == nil && passive.isolationWorkRuntime.review == nil)

    try await IsolationWorkFixture.arm(runtime)
    let armed = await runtime.snapshot()
    let freshArm = try #require(armed.isolationWorkRuntime.arm)
    #expect(freshArm != oldArm && freshArm.epoch == restored.nativeStationRuntimeEpoch)
    #expect(freshArm.job == child.id && freshArm.authority.source == written.source)
    #expect(armed.isolationWorkChild?.savedIsolationWork == unarmed)
    let resumed = await runtime.advance(delta: 0.05)
    let progressed = try #require(resumed.isolationWorkChild?.savedIsolationWork)
    #expect(progressed.producerSequence > unarmed.producerSequence)
    #expect(progressed.modules[0].history.seconds(.work) > unarmed.modules[0].history.seconds(.work))
    #expect(progressed.modules[1].history == unarmed.modules[1].history)
    #expect(progressed.modules.allSatisfy { $0.accounts.valid && $0.opening == nil && $0.verification == nil })
    let active = try #require(resumed.isolationWorkParentMission)
    #expect(active.outcome == .active && active.completionReceipt == nil)
    #expect(active.savedIsolationWorkParent?.terminal == nil && active.savedIsolationWorkParent?.cutoff == nil)
    #expect(resumed.commander.credits == saved.commander.credits && resumed.commander.cargo == saved.commander.cargo)
    #expect(resumed.commander.scriptState.savedClueJournal?.awards[NativeIsolationWorkParent.stateID] == nil)
    #expect(OriginalServiceReservationPolicy.activeCount(resumed.commander.scriptState) == 1)
    #expect(try NativeIsolationProgrammerCustody.resolve(parent: active, commander: resumed.commander) == loan)

    try await runtime.save(to: files.save)
    let final = await runtime.snapshot()
    let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: files.save), from: files.save)
    #expect(cold.isolationInstance(child.id)?.savedIsolationWork == final.isolationWorkChild?.savedIsolationWork)
    #expect(NativeIsolationWorkParentSave.validateClaims(cold))
    #expect(NativeIsolationWorkSave.validateClaims(cold))
    #expect(NativeIsolationContractSave.validateClaims(cold))
  }
}
