import Foundation
import Testing

@testable import L337Core

/// Historical exhausted-scene setup grants no work, contact change, observation or reward.
/// Every claimed work interval below uses the actual admitted pair and native producer.
extension IsolationWorkFixture {
  func exhaustedConnectedScene() throws {
    try connectedCircuitScene(steps: 100_001)
    let state = try state()
    try #require(state.modules.allSatisfy {
      $0.accounts.remainingSupply == 0 && $0.accounts.headroom == 0
    })
  }

  func connectedCircuitScene(steps: Int) throws {
    var child = try #require(game.isolationWorkChild)
    var state = try #require(child.savedIsolationWork)
    try #require(state.modules.allSatisfy { $0.admission != nil && $0.opening == nil })
    var accounts = NativeIsolationEnergyAccounts()
    var before = accounts
    var transferred = 0.0
    for _ in 0..<steps {
      before = accounts
      transferred = try accounts.transfer(seconds: 0.1, contact: .connected)
    }
    try #require(accounts.valid)
    let elapsed = Double(steps) * 0.1
    game.commander.flightSimulation.physicalTime += elapsed
    let end = game.commander.flightSimulation.physicalTime
    state.localSeconds = elapsed
    state.producerSequence = UInt64(steps)
    let actors = try state.modules.map { try #require($0.binding) }
    for index in state.modules.indices {
      state.modules[index].accounts = accounts
      state.modules[index].connectedSeconds = elapsed
      state.modules[index].lastMeter = .init(
        actor: actors[index], peer: actors[1 - index], sequence: state.producerSequence,
        start: end - 0.1, end: end, contact: .connected,
        before: before, after: accounts, transferred: transferred)
    }
    try #require(state.shapeValid)
    child.savedIsolationWork = state
    game.commander.scriptState.instances[child.id] = child
    try #require(NativeIsolationWorkSave.validateClaims(game.commander))
  }

  func measuredStep(publish: ScriptPublisher? = nil) throws {
    let start = try #require(game.isolationWorkSample())
    game.tick(delta: 0.05)
    game.advanceIsolationWork(from: start, publish: publish)
  }
}

private enum IsolationDryWriteError: Error { case refused }

struct NativeIsolationDryCircuitUnitTests {
  // Intentionally accepts the candidate in memory; persistence refusal is tested separately.
  private static let acceptingWriter: ScriptPublisher = { _ in }

  @Test func exhaustedConnectedSourceAloneCannotEarnWorkIsolationOrMoney() async throws {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    try fixture.exhaustedConnectedScene()
    let credits = fixture.game.commander.credits
    for _ in 0..<21 { try fixture.measuredStep(publish: Self.acceptingWriter) }
    let state = try fixture.state()
    #expect(state.modules.allSatisfy {
      $0.contact == .connected && $0.opening == nil && $0.verification == nil
        && $0.history.segments.isEmpty && $0.accounts.remainingSupply == 0
        && $0.accounts.deliveredLoad == 10000
    })
    #expect(fixture.game.commander.credits == credits)
    #expect(fixture.game.isolationWorkParentMission?.outcome == .active)
  }

  @Test func dryMechanicalWorkNeedsTwentySecondsPublishedChangeAndLaterObservation() async throws {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    try fixture.exhaustedConnectedScene()
    try fixture.arm()
    let initial = try fixture.state()
    let credits = fixture.game.commander.credits
    for _ in 0..<399 { try fixture.measuredStep() }
    let short = try fixture.state()
    #expect(short.modules[0].history.seconds(.work) < 20)
    #expect(short.modules[0].opening == nil && short.modules[0].contact == .connected)
    try fixture.measuredStep(publish: { _ in throw IsolationDryWriteError.refused })
    let refused = try fixture.state()
    #expect(abs(refused.modules[0].history.seconds(.work) - 20) < 1e-8)
    #expect(refused.modules[0].contact == .connected && refused.modules[0].opening == nil)
    #expect(refused.modules[0].history.seconds(.observation) == 0)

    try fixture.measuredStep(publish: Self.acceptingWriter)
    let opened = try fixture.state()
    let opening = try #require(opened.modules[0].opening)
    #expect(opening.change.proof == .dryMechanical)
    #expect(opening.change.epoch == fixture.game.nativeStationRuntimeEpoch)
    #expect(opening.change.before == .connected)
    #expect(opening.change.after == opened.modules[0].contact)
    #expect(opening.meter.transferred == 0 && opening.meter.before == opening.meter.after)
    #expect(opened.modules[0].history.segments.allSatisfy { $0.proof == .dryMechanical })
    #expect(opened.modules[0].history.seconds(.observation) == 0)
    #expect(opened.modules[0].verification == nil)
    #expect(opened.modules.map(\.accounts) == initial.modules.map(\.accounts))

    try fixture.measuredStep(publish: Self.acceptingWriter)
    let oneObservation = try fixture.state()
    #expect(oneObservation.modules[0].verification == nil)
    #expect(oneObservation.modules[0].history.seconds(.observation) < 1)
    for _ in 0..<18 { try fixture.measuredStep(publish: Self.acceptingWriter) }
    try fixture.measuredStep(publish: { _ in throw IsolationDryWriteError.refused })
    let uncommittedVerification = try fixture.state()
    #expect(uncommittedVerification.modules[0].contact == opening.change.after)
    #expect(uncommittedVerification.modules[0].verification == nil)
    #expect(abs(uncommittedVerification.modules[0].history.seconds(.observation) - 1) < 1e-8)
    try fixture.measuredStep(publish: Self.acceptingWriter)
    let verified = try fixture.state()
    let receipt = try #require(verified.modules[0].verification)
    #expect(receipt.proof == .dryMechanical && receipt.opening == opening.operation)
    #expect(receipt.valid(opened: opening, history: verified.modules[0].history))
    #expect(receipt.first.sequence > opening.meter.sequence)
    #expect(receipt.last.sequence > receipt.first.sequence)
    #expect(receipt.first.start >= opening.meter.end && receipt.last.end > receipt.first.end)
    #expect(verified.modules.map(\.accounts) == initial.modules.map(\.accounts))
    #expect(verified.modules[1].contact == .connected && verified.modules[1].opening == nil)
    #expect(fixture.game.commander.credits == credits)
    #expect(fixture.game.isolationWorkParentMission?.outcome == .active)
    #expect(NativeIsolationWorkSave.validateClaims(fixture.game.commander))

    let bytes = try JSONEncoder().encode(try #require(fixture.game.isolationWorkChild))
    let decoded = try JSONDecoder().decode(ScriptInstance.self, from: bytes)
    #expect(decoded.savedIsolationWork == verified)
    #expect(decoded.savedIsolationWork?.shapeValid == true)
  }

  enum InvalidAuthority: CaseIterable, Sendable {
    case wrongTool, staleEpoch, outOfRange
  }

  @Test(arguments: InvalidAuthority.allCases)
  func depletedCircuitStillRequiresOriginalToolEpochAndPhysicalEnvelope(
    _ invalid: InvalidAuthority
  ) async throws {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    try fixture.exhaustedConnectedScene()
    try fixture.arm()
    let original = try fixture.state()
    let sample = try #require(fixture.game.isolationWorkSample())
    switch invalid {
    case .wrongTool:
      let inventory = try #require(fixture.game.commander.equipmentInventory)
      let serial = original.permission.programmer
      let item = try #require(inventory.items.first { $0.id == serial })
      let substitute = OwnedEquipmentItem(id: UUID(), node: item.node, provenance: item.provenance)
      fixture.game.commander.savedEquipmentInventory = try .init(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.map { $0.id == serial ? substitute : $0 })
    case .staleEpoch:
      fixture.game.nativeStationRuntimeEpoch = UUID()
    case .outOfRange:
      var pose = fixture.game.commander.flightSimulation.pose
      pose.position = pose.position + .init(0, 0, -1000)
      NativeStationTestFixture.reframe(&fixture.game, to: pose)
    }
    #expect(fixture.game.isolationWorkEndpoint() == nil)
    fixture.game.tick(delta: 0.05)
    fixture.game.advanceIsolationWork(from: sample, publish: nil)
    let refused = try fixture.state()
    #expect(refused.modules.allSatisfy {
      $0.history.segments.isEmpty && $0.contact == .connected && $0.opening == nil
        && $0.verification == nil
    })
    #expect(refused.modules.map(\.accounts) == original.modules.map(\.accounts))
    #expect(fixture.game.isolationWorkRuntime.arm == nil)
  }

  @Test func forgedOpenContactOrRelabelledFlowCannotReplaceNativeMechanicalChange() async throws {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    try fixture.exhaustedConnectedScene()
    var forged = try fixture.state()
    forged.modules[0].contact = .latchedOpen(operation: UUID(), revision: 1)
    #expect(!forged.shapeValid)
    let meter = try #require(forged.modules[0].lastMeter)
    #expect(NativeIsolationProofKind.connectedReading(meter) == .dryMechanical)
    #expect(!NativeIsolationProofKind.energizedFlow.permitsOpening(meter))
    #expect(!NativeIsolationProofKind.energizedFlow.matchesIsolatedAccounts(meter.after))

    try fixture.arm()
    for _ in 0..<400 { try fixture.measuredStep(publish: Self.acceptingWriter) }
    let opened = try fixture.state()
    let receipt = try #require(opened.modules[0].opening)
    var missingChange = opened
    missingChange.modules[0].contact = .connected
    #expect(!missingChange.shapeValid)
    let alienChange = NativeIsolationContactChange(
      epoch: receipt.change.epoch, source: UUID(), module: receipt.change.module,
      supply: receipt.change.supply, load: receipt.change.load,
      before: .connected, after: receipt.change.after, proof: .dryMechanical)
    #expect(!alienChange.valid(
      authority: receipt.authority, operation: receipt.operation,
      revision: receipt.contactRevision, meter: receipt.meter))
    #expect(opened.modules[0].verification == nil)
  }

  @Test func depletionDuringRealWorkKeepsAttainedWorkAndRecordsBothProofKinds() async throws {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    try fixture.connectedCircuitScene(steps: 99_995)
    try fixture.arm()
    for _ in 0..<400 { try fixture.measuredStep(publish: Self.acceptingWriter) }
    let state = try fixture.state()
    let module = state.modules[0]
    let opening = try #require(module.opening)
    #expect(abs(module.history.seconds(.work) - 20) < 1e-8)
    #expect(module.history.segments.first?.proof == .energizedFlow)
    #expect(module.history.segments.last?.proof == .dryMechanical)
    #expect(opening.change.proof == .dryMechanical && opening.meter.transferred == 0)
    #expect(module.accounts.remainingSupply == 0 && module.accounts.deliveredLoad == 10000)
    #expect(module.verification == nil && module.history.seconds(.observation) == 0)
    #expect(NativeIsolationWorkSave.validateClaims(fixture.game.commander))
  }
}
