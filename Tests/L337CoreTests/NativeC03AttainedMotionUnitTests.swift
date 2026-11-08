import Foundation
import Testing

@testable import L337Core

/// Controlled initial location/control inputs are not a flown journey. Every positive source
/// comes from the shared actual commission/admission fixture; no State/pin/motion proof is injected.
struct NativeC03AttainedMotionUnitTests {
  private func requireRecord(_ game: Game) throws -> NativeC03AttainedMotion {
    guard case .recorded(let record)? = game.nativeC03AttainedMotion else {
      Issue.record(
        "Genuine native moving frame must produce raw C03 data before refusal assertions")
      throw SaveError.invalidCommander
    }
    try #require(record.originals.count == 2 && record.endTime > record.startTime)
    return record
  }

  private var movingControls: Controls {
    var controls = Controls()
    controls.throttle = 0.25
    controls.pitch = 0.05
    controls.roll = 0.03
    return controls
  }

  private func nativeStep(_ game: inout Game, capture: Bool = true) throws {
    if capture { game.beginC03AttainedMotionStep() }
    game.tick(delta: 0.1, controls: movingControls)
    try game.persistScriptActorsChecked()
    try game.restoreScriptActors()
    if capture { game.finishC03AttainedMotionStep() }
  }

  @Test func actualRuntimeFrameRecordsPlayerAndBothLatePoweredOriginalSteps() async throws {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    let initial = actual.game
    try #require(initial.c03LiveRouteInputs().originals.count == 2)
    let runtime = GameRuntime(game: initial)
    await runtime.setControls(movingControls)
    let after = await runtime.advance(delta: 0.5)
    let record = try requireRecord(after)
    #expect(abs(record.endTime - record.startTime - 0.1) < 1e-9)
    #expect(record.playerPhase.before == initial.commander.flightSimulation.pose)
    #expect(record.playerPhase.after == after.commander.flightSimulation.pose)
    #expect(record.playerPhase.after.position != record.playerPhase.before.position)
    #expect(
      record.frame == after.gameplayRevision
        && record.player == after.commander.flightSimulation.player)
    #expect(
      !record.playerPhase.work && record.playerPhase.manual != nil && record.acceptedWork == nil)
    for original in record.originals {
      let body = try #require(after.bodies.first { $0.id == original.powered.after.id })
      let velocity = try #require(original.powered.after.scriptNPC?.velocity)
      #expect(velocity.length > 0)
      #expect(original.powered.delta == record.playerPhase.delta)
      #expect(
        (original.powered.after.position - original.powered.before.position
          - velocity * original.powered.delta).length < 1e-9)
      #expect(original.rootEnd == after.modelPose(of: body))
      #expect(original.admission.original.actor == body.physical?.identity)
      #expect(original.admission.spawn == body.physical?.spawnIdentity)
      #expect(original.routeEnd.admission == original.routeStart.admission)
    }
    #expect(after.nativeC03MotionPending == nil)
  }

  @Test func rawCaptureDoesNotIntegrateAgainOrChangeActualPhysicsAndSourceHistory() async throws {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var captured = actual.game
    var ordinary = actual.game
    try nativeStep(&captured)
    _ = try requireRecord(captured)
    try nativeStep(&ordinary, capture: false)
    #expect(captured.commander == ordinary.commander)
    #expect(captured.bodies == ordinary.bodies && captured.celestials == ordinary.celestials)
    #expect(captured.nativeC03MotionPending == nil && ordinary.nativeC03AttainedMotion == nil)
  }

  @Test func actualAcceptedWorkBranchRetainsItsOwnAppliedModelWithoutSupplyingAProof() async throws
  {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var game = actual.game
    // Controlled residual control state only. The existing controller/sweep must generate and
    // actually apply its own accepted HullSceneMotion; no numeric motion DTO is supplied.
    game.workBraking = .init(velocity: .init(1, 0, 0), angularVelocity: .init(0, 0.02, 0))
    let runtime = GameRuntime(game: game)
    let after = await runtime.advance(delta: 0.1)
    let record = try requireRecord(after)
    let applied = try #require(after.lastAppliedWorkMotion)
    try #require(
      record.playerPhase.work && record.playerPhase.manual == nil
        && record.acceptedWork != nil)
    #expect(record.acceptedWork?.start == applied.start && record.acceptedWork?.end == applied.end)
    #expect(applied.end == after.commander.flightSimulation.pose)
    #expect(record.acceptedWork?.duration == record.endTime - record.startTime)
  }

  @Test(arguments: ["body", "inventory", "scene", "emission", "epoch"])
  func genuineMovingControlPrecedesLateMutationRefusalAndRefusalPreservesPhysics(reason: String)
    async throws
  {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var control = actual.game
    try nativeStep(&control)
    _ = try requireRecord(control)
    var game = actual.game
    game.beginC03AttainedMotionStep()
    game.tick(delta: 0.1, controls: movingControls)
    try game.persistScriptActorsChecked()
    try game.restoreScriptActors()
    let original = try #require(game.c03LiveRouteInputs().originals.first)
    let index = try #require(game.bodies.firstIndex { $0.id == original.owned.body.id })
    switch reason {
    case "body": game.bodies[index].position.x += 1
    case "inventory":
      // Negative-only revision corruption; it creates no item or live frame authority.
      let inventory = try #require(game.commander.equipmentInventory)
      game.commander.savedEquipmentInventory = try .init(
        owner: inventory.owner, activeHull: inventory.activeHull,
        revision: inventory.revision + 1, items: inventory.items)
    case "scene":
      let id = game.nextBodyID
      game.nextBodyID += 1
      game.bodies.append(.init(id: id, hull: .cargo, position: .init(0, 0, 500)))
      game.ensurePhysicalActors()
    case "emission":
      let before = game.commander.flightSimulation.nextEmission
      game.fireLaser()
      try #require(game.commander.flightSimulation.nextEmission > before)
    default: game.nativeStationRuntimeEpoch = UUID()
    }
    let before = game.commander
    let bodies = game.bodies
    game.finishC03AttainedMotionStep()
    if case .recorded? = game.nativeC03AttainedMotion {
      Issue.record("Unsupported late mutation must not produce raw accepted-frame data")
    }
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.nativeC03MotionPending == nil)
  }

  @Test func missingActualMutationPhasesCannotBeReplacedByAClockOrEndpoint() async throws {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var control = actual.game
    try nativeStep(&control)
    _ = try requireRecord(control)
    var game = actual.game
    game.beginC03AttainedMotionStep()
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    let before = game.commander
    let bodies = game.bodies
    game.finishC03AttainedMotionStep()
    guard case .refused(.missingPhase)? = game.nativeC03AttainedMotion else {
      Issue.record("Clock advancement without actual phases must be an explicit refusal")
      return
    }
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test func zeroStepAndPauseCannotReuseThePriorCurrentFrameRecord() async throws {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    let runtime = GameRuntime(game: actual.game)
    await runtime.setControls(movingControls)
    let moving = await runtime.advance(delta: 0.1)
    _ = try requireRecord(moving)
    let zero = await runtime.advance(delta: 0)
    if case .recorded? = zero.nativeC03AttainedMotion {
      Issue.record("Zero physical step must not retain old frame data")
    }
    #expect(
      zero.commander.flightSimulation.physicalTime == moving.commander.flightSimulation.physicalTime
    )
    var paused = moving
    paused.paused = true
    let stopped = GameRuntime(game: paused)
    let result = await stopped.advance(delta: 0.1)
    if case .recorded? = result.nativeC03AttainedMotion {
      Issue.record("Pause must not reuse an old motion record")
    }
    #expect(
      result.commander.flightSimulation.physicalTime
        == moving.commander.flightSimulation.physicalTime)
  }

  @Test func foreignOpaqueActorIsExplicitlyUnsupportedRatherThanOmittedFromTheScene()
    async throws
  {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var control = actual.game
    try nativeStep(&control)
    _ = try requireRecord(control)
    var game = actual.game
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cargo, position: .init(0, 0, 500)))
    game.ensurePhysicalActors()
    let before = game.commander
    let bodies = game.bodies
    game.beginC03AttainedMotionStep()
    guard case .refused(.unsupportedScene)? = game.nativeC03AttainedMotion else {
      Issue.record("A foreign opaque actor must be explicitly unsupported, never left out")
      return
    }
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.nativeC03MotionPending == nil)
  }

  @Test(arguments: ["condition", "inertia"])
  func stationMutationBeforeCameraCaptureRefusesAfterGenuineMovingControl(reason: String)
    async throws
  {
    let actual = try await actualHollowManifestFreighterRootFixture()
    defer { actual.commission.clean() }
    var control = actual.game
    try nativeStep(&control)
    _ = try requireRecord(control)
    var game = actual.game
    game.beginC03AttainedMotionStep()
    let station = try #require(game.bodies.firstIndex { $0.id == 0 && $0.hull == .station })
    if reason == "condition" {
      game.bodies[station].energy += 1
    } else {
      game.bodies[station].physical?.velocity = .init(1, 0, 0)
    }
    game.tick(delta: 0.1, controls: movingControls)
    try game.persistScriptActorsChecked()
    try game.restoreScriptActors()
    let before = game.commander
    let bodies = game.bodies
    game.finishC03AttainedMotionStep()
    guard case .refused(.changedScene)? = game.nativeC03AttainedMotion else {
      Issue.record(
        "Unowned station condition/inertia changes must not be normalized as camera motion")
      return
    }
    #expect(game.commander == before && game.bodies == bodies)
  }

}
