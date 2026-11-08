import Foundation
import Testing

@testable import L337Core

struct NativeIsolationEpochUnitTests {
  @Test func replacingRuntimeEpochRejectsOldPhysicalSampleWithoutTransferringEnergy() async throws {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    try fixture.arm()
    let before = try fixture.state()
    let sample = try #require(fixture.game.isolationWorkSample())

    // The old sample and arm cannot bridge a runtime replacement, even when the
    // same current-format actors, account values and mission remain present.
    fixture.game.nativeStationRuntimeEpoch = UUID()
    fixture.game.tick(delta: 0.05)
    fixture.game.advanceIsolationWork(from: sample, publish: nil)

    let after = try fixture.state()
    #expect(after == before)
    #expect(fixture.game.isolationWorkRuntime.arm == nil)
    #expect(after.modules.allSatisfy { $0.history.seconds(.work) == 0 })
  }

  @Test func rearmingInCurrentEpochRequiresAndCreditsANewPhysicalInterval() async throws {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    try fixture.arm()
    fixture.game.nativeStationRuntimeEpoch = UUID()
    fixture.game.interruptIsolationWork()
    let reviewed = fixture.game.handleIsolationWorkKey("return")
    let armed = fixture.game.handleIsolationWorkKey("return")
    try #require(reviewed && armed && fixture.game.isolationWorkEndpoint() != nil)

    let before = try fixture.state()
    try fixture.tick()
    let after = try fixture.state()
    #expect(after.producerSequence == before.producerSequence + 1)
    #expect(after.localSeconds > before.localSeconds)
    #expect(after.modules.allSatisfy { $0.accounts.deliveredLoad > 0 })
    #expect(after.modules.reduce(0) { $0 + $1.history.seconds(.work) } > 0)
    #expect(after.modules.allSatisfy { $0.opening == nil && $0.verification == nil })

    // Real runtime construction invalidates both UI phases, retaining actual attained
    // work and the unpublished source-account checkpoint instead of resetting the source.
    for reviewing in [false, true] {
      var ready = fixture.game
      if reviewing {
        ready.interruptIsolationWork()
        let reopened = ready.handleIsolationWorkKey("return")
        try #require(reopened)
        try #require(ready.isolationWorkRuntime.review != nil && ready.isolationWorkRuntime.arm == nil)
      } else {
        try #require(ready.isolationWorkRuntime.arm != nil && ready.isolationWorkRuntime.review == nil)
      }
      let beforeCommander = ready.commander
      let beforeEpoch = ready.nativeStationRuntimeEpoch
      let pending = ready.isolationWorkRuntime
      try #require(pending.dirty)
      let runtime = GameRuntime(game: ready)
      let reset = await runtime.snapshot()
      #expect(reset.nativeStationRuntimeEpoch != beforeEpoch)
      #expect(reset.isolationWorkRuntime.contact == nil)
      #expect(reset.isolationWorkRuntime.review == nil && reset.isolationWorkRuntime.arm == nil)
      #expect(reset.isolationWorkEndpoint() == nil)
      #expect(reset.isolationWorkRuntime.dirty == pending.dirty)
      #expect(reset.isolationWorkRuntime.publishedTime == pending.publishedTime)
      #expect(reset.isolationWorkRuntime.reason == pending.reason)
      #expect(reset.isolationWorkChild?.savedIsolationWork == after)
      let commanderUnchanged = reset.commander == beforeCommander
      #expect(commanderUnchanged)
    }
  }
}
