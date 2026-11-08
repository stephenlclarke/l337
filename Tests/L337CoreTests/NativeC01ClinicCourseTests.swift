import Foundation
import Testing

@testable import L337Core

private func expectClinicControlFactsEqual(
  _ before: [NativeC01ClinicControlProof], _ after: [NativeC01ClinicControlProof]
) throws {
  try #require(before.count == after.count)
  for (left, right) in zip(before, after) {
    #expect(left.actor == right.actor && left.epoch == right.epoch)
    #expect(left.startTime == right.startTime && left.duration == right.duration)
    #expect(left.from == right.from && left.proposedOrientation == right.proposedOrientation)
    #expect(left.steeringTravel == right.steeringTravel)
    #expect(left.nativeAngularVelocity == right.nativeAngularVelocity)
  }
}

private func expectClinicCourseSceneUnchanged(_ before: Game, _ after: Game) throws {
  #expect(after.commander == before.commander && after.scriptWorldSave == before.scriptWorldSave)
  #expect(after.bodies == before.bodies && after.celestials == before.celestials)
  #expect(after.energy == before.energy && after.frontShield == before.frontShield)
  #expect(after.rearShield == before.rearShield && after.nextBodyID == before.nextBodyID)
  #expect(after.screen == before.screen && after.message == before.message)
  #expect(after.messageTime == before.messageTime && after.weaponsTargetID == before.weaponsTargetID)
  #expect(after.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
  #expect(after.c01ClinicEscortRuntime.review === before.c01ClinicEscortRuntime.review)
  #expect(after.c01ClinicEscortRuntime.attainedSample === before.c01ClinicEscortRuntime.attainedSample)
  try #require(after.c01ClinicEscortRuntime.pendingDeaths.count == before.c01ClinicEscortRuntime.pendingDeaths.count)
  for (left, right) in zip(before.c01ClinicEscortRuntime.pendingDeaths,
    after.c01ClinicEscortRuntime.pendingDeaths) {
    #expect(left === right)
  }
}

private func expectClinicCourseReadOnly(_ before: Game, _ after: Game) throws {
  try expectClinicCourseSceneUnchanged(before, after)
  try expectClinicControlFactsEqual(before.c01ClinicEscortRuntime.controls,
    after.c01ClinicEscortRuntime.controls)
  #expect(after.c01ClinicEscortRuntime.reason == before.c01ClinicEscortRuntime.reason)
}

struct NativeC01ClinicCourseTests {
  @Test(arguments: [false, true])
  func actualClinicCourseIsReadOnlyAndNativeGuidanceRetainsSourceTimeAndEpoch(_ operating: Bool)
    async throws
  {
    let fixture = try await C01ClinicPeopleJourneyFixture()
    defer { fixture.clean() }
    var sourceGame = try await fixture.sourceGame()
    if operating { try fixture.parkAtCradle(&sourceGame) }
    let runtime = GameRuntime(game: sourceGame, saveURL: fixture.save)
    try await runtime.save(to: fixture.save)
    if operating {
      // Only the existing actual launch review/confirmation creates consent and assignment.
      await runtime.key("return")
      try #require(await runtime.snapshot().c01ClinicEscortRuntime.review != nil)
      await runtime.key("return")
      let released = await runtime.snapshot()
      try #require(released.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.current != nil)
    }
    _ = await runtime.advance(delta: 0.05)
    var game = await runtime.snapshot()
    let source = try #require(game.commander.nativePeople?.clinicSource)
    let unit = try #require(source.unit(0))
    let bodyCandidate = game.bodies.first { $0.missionActorID == unit.actor }
    let body = try #require(bodyCandidate)
    let physical = try #require(body.physical)
    let profile = try #require(body.scriptNPC?.fit.definition)
    let mission = try #require(game.glassMeridianMission)
    let state = try #require(mission.savedGlassMeridian?.clinicEscort)
    try #require(NativeC01ClinicPeopleSave.sourceClaimsMatch(state, mission: mission,
      commander: game.commander))
    let ownedPreparationRequired1 = game.c01ClinicStockOrdinal(body) == 0
    try #require(ownedPreparationRequired1)
    let pilot = try #require(game.commander.c01ClinicStockPilotFacts(ordinal: 0))
    if operating {
      let launch = try #require(state.current)
      try #require(pilot.location == .aboardOperating(launch: launch.operation))
    } else {
      try #require(state.current == nil && pilot.location == .aboardStored)
    }
    let sample = try #require(game.c01ClinicEscortRuntime.attainedSample)
    try #require(sample.epoch == game.nativeStationRuntimeEpoch)
    try #require(abs(game.commander.flightSimulation.physicalTime - sample.native.physicalTime - 0.05) < 1e-10)
    let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let ownedPreparationRequired2 = game.c01ClinicCourse(body, profile: profile, delta: 0.05)
    let course = try #require(ownedPreparationRequired2)
    // A real time-bound clinic source remains a special controller at the
    // actual opening. Ordinary NPC preparation must refuse without moving a
    // copied production Game to a later clock to decide eligibility.
    let pathCandidate = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(pathCandidate)
    #expect(game.prepareCurrentNewtNPCFrame(path) == nil)
    try expectClinicCourseReadOnly(game, await runtime.snapshot())
    let ownedPreparationRequired3 = game.c01ClinicCourse(body, profile: profile, delta: 0.05)
    let repeated = try #require(ownedPreparationRequired3)
    #expect(repeated.worldVelocity == course.worldVelocity && repeated.worldOrientation == course.worldOrientation)
    #expect(repeated.angularTravel == course.angularTravel && repeated.status == course.status)
    let snapshot = game.bodies
    let owned = Dictionary(snapshot.compactMap { value in
      value.missionActorID.map { ($0, value) }
    }, uniquingKeysWith: { first, _ in first })
    let station = snapshot.first { $0.id == 0 && $0.hull == .station }
    let ownedPreparationRequired4 = game.prepareScriptNPCFlightDecision(body,
      owned: owned, station: station, delta: 0.05)
    let decision = try #require(ownedPreparationRequired4)
    #expect(decision.orientation == course.worldOrientation.relative(to: game.commander.flightSimulation.pose.orientation))
    #expect(decision.pending == nil && decision.intent == body.scriptNPC?.intent)
    try expectClinicCourseReadOnly(game, await runtime.snapshot())
    #expect(try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent()) == files)

    // The old actual guidance creates the real transient control proof; no test
    // constructs a proof, clock sample, stock, pilot or receiving witness.
    var installed = game
    let resultCandidate = installed.c01ClinicGuidance(body, profile: profile, delta: 0.05)
    let result = try #require(resultCandidate)
    try expectClinicCourseSceneUnchanged(game, installed)
    #expect(result.orientation == decision.orientation)
    #expect(result.desired == game.commander.flightSimulation.pose.shipVector(course.worldVelocity))
    #expect(installed.c01ClinicEscortRuntime.reason == course.status)
    try expectClinicControlFactsEqual(game.c01ClinicEscortRuntime.controls.filter { $0.actor != physical.identity },
      installed.c01ClinicEscortRuntime.controls.filter { $0.actor != physical.identity })
    let selected = installed.c01ClinicEscortRuntime.controls.filter { $0.actor == physical.identity }
    try #require(selected.count == 1)
    let proof = try #require(selected.first)
    #expect(proof.epoch == game.nativeStationRuntimeEpoch && proof.startTime == sample.native.physicalTime)
    #expect(proof.duration == 0.05 && proof.from == game.modelPose(of: body))
    #expect(proof.proposedOrientation == course.worldOrientation && proof.steeringTravel == course.angularTravel)
    let endpoint = ShipPose(position: proof.from.position, orientation: course.worldOrientation)
    let turn = try #require(proof.angularTravel(actor: physical.identity, epoch: proof.epoch,
      from: proof.from, to: endpoint, startTime: proof.startTime, duration: proof.duration,
      includesNativeSpin: false))
    #expect(turn == course.angularTravel)
    let reserve = try #require(source.unit(1))
    let reserveBodyCandidate = game.bodies.first { $0.missionActorID == reserve.actor }
    let reserveBody = try #require(reserveBodyCandidate)
    let other = try #require(reserveBody.physical?.identity)
    #expect(proof.angularTravel(actor: other, epoch: proof.epoch, from: proof.from, to: endpoint,
      startTime: proof.startTime, duration: proof.duration, includesNativeSpin: false) == nil)
    #expect(proof.angularTravel(actor: physical.identity, epoch: UUID(), from: proof.from, to: endpoint,
      startTime: proof.startTime, duration: proof.duration, includesNativeSpin: false) == nil)
    #expect(proof.angularTravel(actor: physical.identity, epoch: proof.epoch, from: proof.from, to: endpoint,
      startTime: proof.startTime + 0.01, duration: proof.duration, includesNativeSpin: false) == nil)
    #expect(proof.angularTravel(actor: physical.identity, epoch: proof.epoch, from: proof.from, to: endpoint,
      startTime: proof.startTime, duration: proof.duration * 0.5, includesNativeSpin: false) == nil)

    // Wrong source is a negative alias substitution only, never a positive admission.
    var foreign = body
    foreign.missionActorID = reserve.actor
    var refused = game
    #expect(refused.c01ClinicCourse(foreign, profile: profile, delta: 0.05) == nil)
    #expect(refused.c01ClinicGuidance(foreign, profile: profile, delta: 0.05) == nil)
    for invalid in [0.0, -0.05, 0.10001, Double.nan, Double.infinity] {
      #expect(refused.c01ClinicCourse(body, profile: profile, delta: invalid) == nil)
      #expect(refused.c01ClinicGuidance(body, profile: profile, delta: invalid) == nil)
    }
    try expectClinicCourseReadOnly(game, refused)
    #expect(try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent()) == files)
  }
}
