import Foundation
import Testing

@testable import L337Core

struct NativeC01ClinicEscortUnitTests {
  @Test func originalCradleDecodesMetresOpenNativePortAndStructuralBudget() throws {
    let cradle = try NativeC01ClinicCradle.original.get()
    let port = cradle.nativeDocking.port
    #expect(cradle.metresPerSourceUnit == 1)
    #expect(cradle.massKilograms == 315120)
    #expect(cradle.nativeDesign.vertices.count == 64 && cradle.nativeDesign.faces.count == 144)
    #expect(cradle.design == cradle.nativeDesign)
    #expect(try PreparedHull(mesh: cradle.nativeDesign.rawMesh).isClosed)
    #expect(port.valid && port.center == .init(0, 0, 40) && port.tunnelDepth == 80)
    #expect(port.aperture.count == 4)
    let tender = try NativeC01SurveyorGeometry.harrier.get()
    // Static containment is only a decoder/geometry prerequisite, not an attained exit proof.
    #expect(port.fits(tender.collision, margin: 5))
    #expect(cradle.structuralPolicy.energy == 100 && cradle.structuralPolicy.crew == 0)
  }

  @Test func cradleRejectsFakeWorkFaceForeignProvenanceScaleAndClosedAperture() throws {
    let encoded = try JSONEncoder().encode(NativeC01ClinicCradle.original.get())
    let source = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var mutations: [[String: Any]] = []
    for (key, value) in [("interactionFace", [:] as Any), ("metresPerSourceUnit", 80 as Any),
                         ("sourcePath", "outer-cradle.toml" as Any),
                         ("sourceSHA256", "foreign" as Any)] {
      var changed = source
      changed[key] = value
      mutations.append(changed)
    }
    var docking = try #require(source["nativeDocking"] as? [String: Any])
    docking["aperture"] = []
    var changed = source
    changed["nativeDocking"] = docking
    mutations.append(changed)
    for changed in mutations {
      let bytes = try JSONSerialization.data(withJSONObject: changed, options: [.sortedKeys])
      #expect(throws: (any Error).self) { try NativeC01ClinicCradle.decode(bytes) }
    }
    #expect(throws: (any Error).self) { try NativeC01ClinicCradle.decode(Data()) }
  }

  @Test func healthyClinicProfileUsesSameOriginalHarrierWithoutDisabledConditionOrRoleKit() throws {
    let original = try NativeC01SurveyorGeometry.harrier.get()
    let clinic = try NativeC01ClinicEscort.profile(cradle: false)
    #expect(clinic.energy == original.performance.energy)
    #expect(clinic.recharge == original.performance.recharge)
    #expect(clinic.speed == original.performance.speed * 18)
    #expect(clinic.acceleration == original.performance.acceleration * 18)
    #expect(clinic.pitch == original.performance.pitch && clinic.yaw == original.performance.yaw)
    #expect(clinic.fuel == 0 && clinic.drive == nil && clinic.missiles == 0 && !clinic.ecm)
    #expect((clinic.lasers ?? []).isEmpty && (clinic.components ?? []).isEmpty)
    #expect(clinic.energy == 390 && clinic.speed > 0)
    let cradle = try NativeC01ClinicEscort.profile(cradle: true)
    #expect(cradle.energy == 100 && cradle.speed == 0 && cradle.acceleration == 0)
  }

  @Test func guidanceBeyondAdvertisedTetherProposesHoldWithoutMovingAnything() throws {
    let tender = ShipPose()
    let result = try NativeC01ClinicEscort.guidance(
      tender: tender, player: .init(position: .init(0, 0, -1500.1)),
      station: .init(position: .init(0, 0, -20000)), stationVelocity: .init(0, 0, 0),
      cradle: .init(), profile: NativeC01ClinicEscort.profile(cradle: false), delta: 0.05)
    #expect(result.worldVelocity == .init(0, 0, 0))
    #expect(result.worldOrientation == tender.orientation)
    #expect(tender == ShipPose())
  }

  @Test func sourceExitGuidanceUsesActualOpenPortForwardAndBoundedSpeed() throws {
    let cradle = ShipPose(position: .init(100, 200, 300))
    let result = try NativeC01ClinicEscort.guidance(
      tender: cradle, player: .init(position: .init(100, 200, 500)),
      station: .init(position: .init(0, 0, -20000)), stationVelocity: .init(0, 0, 0),
      cradle: cradle, profile: NativeC01ClinicEscort.profile(cradle: false), delta: 0.05)
    #expect(result.worldOrientation == cradle.orientation)
    #expect(result.worldVelocity == .init(0, 0, 30))
    #expect(cradle.position == .init(100, 200, 300))
  }

  @Test func uncommittedNativeCrossingGuidesRealBackoutForFreshReapproach() throws {
    let port = MainStationGeometry.docking
    var inward = Basis3()
    inward.z = port.outward * -1
    inward.y = port.up
    inward.x = inward.y.cross(inward.z)
    inward.rotate(pitch: 0, roll: 0, yaw: 0.1)
    let profile = try NativeC01ClinicEscort.profile(cradle: false)
    let interval = 0.05
    let tender = ShipPose(position: port.center - port.outward * 0.5, orientation: inward)
    let result = try NativeC01ClinicEscort.guidance(
      tender: tender, player: .init(position: port.center + port.outward * 100),
      station: .init(), stationVelocity: .init(0, 0, 0),
      cradle: .init(position: .init(0, -5000, 20000)),
      profile: profile, delta: interval)
    #expect(result.worldVelocity.dot(port.outward) > 0)
    #expect(result.worldOrientation.z.dot(port.outward) < -0.99)
    #expect(tender.position == port.center - port.outward * 0.5)
    #expect(result.worldOrientation != tender.orientation)
    #expect(result.angularTravel.isFinite && result.angularTravel > 0)
    #expect(abs(result.angularTravel - min(0.1, profile.yaw * interval)) < 1e-10)
    #expect(result.angularTravel <= (profile.pitch + profile.yaw + profile.roll) * interval + 1e-10)
    #expect(result.worldVelocity.length <= min(profile.speed, 30) + 1e-10)
  }
}

extension NativeC01ClinicEscortUnitTests {
  @Test func parkedPilotsHoldDistinctActualBerthsWithoutInventingRotation() throws {
    let profile = try NativeC01ClinicEscort.profile(cradle: false)
    let cradle = ShipPose(position: .init(100, 200, 300))
    let front = NativeC01ClinicEscort.parkedPose(cradle: cradle, ordinal: 0)
    let reserve = NativeC01ClinicEscort.parkedPose(cradle: cradle, ordinal: 1)
    #expect(front.position == .init(100, 200, 318))
    #expect(reserve.position == .init(100, 200, 282))
    for ordinal in 0..<2 {
      let current = NativeC01ClinicEscort.parkedPose(cradle: cradle, ordinal: ordinal)
      let result = try NativeC01ClinicEscort.parkedGuidance(tender: current, cradle: cradle,
        cradleVelocity: .init(0, 0, 0), cradleAngularVelocity: .init(0, 0, 0),
        ordinal: ordinal, profile: profile, delta: 0.05)
      #expect(result.worldVelocity == .init(0, 0, 0))
      #expect(result.worldOrientation == current.orientation && result.angularTravel == 0)
    }
    #expect(throws: (any Error).self) {
      try NativeC01ClinicEscort.parkedGuidance(tender: front, cradle: cradle,
        cradleVelocity: .init(0, 0, 0), cradleAngularVelocity: .init(0, 0, 0),
        ordinal: 2, profile: profile, delta: 0.05)
    }
  }

  @Test func movingCradleBerthGuidanceUsesActualOmegaCrossOffsetAndDoesNotTeleport() throws {
    let profile = try NativeC01ClinicEscort.profile(cradle: false)
    let cradle = ShipPose()
    let before = NativeC01ClinicEscort.parkedPose(cradle: cradle, ordinal: 0)
    let result = try NativeC01ClinicEscort.parkedGuidance(tender: before, cradle: cradle,
      cradleVelocity: .init(2, 0, 0), cradleAngularVelocity: .init(0, 0.1, 0),
      ordinal: 0, profile: profile, delta: 0.05)
    #expect(abs(result.worldVelocity.x - 3.8) < 1e-10)
    #expect(result.worldVelocity.y == 0 && result.worldVelocity.z == 0)
    #expect(before.position == .init(0, 0, 18))
  }

  @Test func steeringReportsAppliedAngularPathAndRetainsOriginalRateLimits() throws {
    let profile = try NativeC01ClinicEscort.profile(cradle: false)
    var turned = Basis3()
    turned.rotate(pitch: 0.1, roll: 0.1, yaw: 0.1)
    let result = try NativeC01ClinicEscort.parkedGuidance(
      tender: .init(position: .init(0, 0, 18), orientation: turned), cradle: .init(),
      cradleVelocity: .init(0, 0, 0), cradleAngularVelocity: .init(0, 0, 0),
      ordinal: 0, profile: profile, delta: 0.05)
    #expect(result.angularTravel > 0)
    #expect(result.angularTravel <= (profile.pitch + profile.yaw + profile.roll) * 0.05 + 1e-12)
    #expect(result.worldOrientation != turned)
  }

  @Test func originalWholeHullSweepKeepsSixMetrePairGapAndBlocksReserveBehindFront() throws {
    let original = try NativeC01SurveyorGeometry.harrier.get()
    let hull = try PreparedHull(mesh: original.collision)
    let cradle = try PreparedHull(mesh: NativeC01ClinicCradle.original.get().nativeDesign.rawMesh)
    let front = NativeC01ClinicEscort.parkedPose(cradle: .init(), ordinal: 0)
    let reserve = NativeC01ClinicEscort.parkedPose(cradle: .init(), ordinal: 1)
    let duration = 0.1
    func sweep(from: ShipPose, velocity: Vector3, other: ShipPose) -> Bool {
      let motion = HullSceneMotion(start: from,
        end: .init(position: from.position + velocity * duration, orientation: from.orientation),
        initialVelocity: velocity, acceleration: .init(0, 0, 0),
        worldAngularVelocity: .init(0, 0, 0), duration: duration,
        playerRadius: hull.radius, requiredClearance: 0)
      let obstacles: [HullSweepObstacle] = [
        .init(hull: hull, pose: other, clearanceOverride: 5),
        .init(hull: cradle, pose: .init(), clearanceOverride: 5),
      ]
      return HullSweepSafety.validateSceneMotion(motion, player: hull, obstacles: obstacles).safe
    }
    #expect(sweep(from: front, velocity: .init(0, 0, 0), other: reserve))
    #expect(sweep(from: front, velocity: .init(0, 0, 30), other: reserve))
    // The same original front mesh blocks the reserve even if its actor is a wreck.
    #expect(!sweep(from: reserve, velocity: .init(0, 0, 30), other: front))
    // Native admission must refine all three close source pairs, never exempt them by ID.
    let frame = NativeC01ClinicEscort.cradleTarget
    let first = NativeC01ClinicEscort.stockTarget(0)
    let second = NativeC01ClinicEscort.stockTarget(1)
    #expect(NativeC01ClinicEscort.sourceAdmissionPairSeparated(
      first: frame, pose: .init(), second: first, other: front))
    #expect(NativeC01ClinicEscort.sourceAdmissionPairSeparated(
      first: second, pose: reserve, second: frame, other: .init()))
    #expect(NativeC01ClinicEscort.sourceAdmissionPairSeparated(
      first: first, pose: front, second: second, other: reserve))
    #expect(!NativeC01ClinicEscort.sourceAdmissionPairSeparated(
      first: "foreign-clinic-member", pose: .init(), second: first, other: front))
    #expect(!NativeC01ClinicEscort.sourceAdmissionPairSeparated(
      first: first, pose: front, second: first, other: reserve))
    #expect(!NativeC01ClinicEscort.sourceAdmissionPairSeparated(
      first: first, pose: front, second: second, other: front))
    #expect(!NativeC01ClinicEscort.sourceAdmissionPairSeparated(
      first: frame, pose: .init(), second: first,
      other: .init(position: .init(.nan, 0, 0))))
    var malformed = front
    malformed.orientation.x = .init(2, 0, 0)
    #expect(!NativeC01ClinicEscort.sourceAdmissionPairSeparated(
      first: frame, pose: .init(), second: first, other: malformed))
    let farthest = try #require(original.collision.vertices.max { $0.length < $1.length })
    var basis = Basis3()
    basis.z = farthest.unit
    let axis = abs(basis.z.y) < 0.9 ? Vector3(0, 1, 0) : .init(1, 0, 0)
    basis.y = (axis - basis.z * axis.dot(basis.z)).unit
    basis.x = basis.y.cross(basis.z)
    var rotatedReserve = reserve
    rotatedReserve.orientation = basis.transposed
    basis.z = basis.z * -1
    basis.x = basis.y.cross(basis.z)
    var rotatedFront = front
    rotatedFront.orientation = basis.transposed
    try #require(rotatedFront.orientation.validRotation)
    try #require(rotatedReserve.orientation.validRotation)
    let frontVertex = rotatedFront.systemPoint(farthest)
    let reserveVertex = rotatedReserve.systemPoint(farthest)
    // Same original berth centres; actual hull vertices are now less than 0.4m apart.
    try #require((frontVertex - reserveVertex).length < 0.4)
    #expect(!NativeC01ClinicEscort.sourceAdmissionPairSeparated(
      first: first, pose: rotatedFront, second: second, other: rotatedReserve))
  }
}

private extension C01ClinicPeopleJourneyFixture {
  func pointAtClinicStock(_ game: inout Game, ordinal: Int = 0) throws -> UUID {
    let source = try #require(game.commander.nativePeople?.clinicSource)
    let unit = try #require(source.unit(ordinal))
    let body = try #require(game.bodies.first { $0.missionActorID == unit.actor })
    let pose = game.modelPose(of: body)
    var facing = Basis3()
    facing.z = pose.orientation.z * -1
    facing.y = pose.orientation.y
    facing.x = facing.y.cross(facing.z)
    NativeStationTestFixture.reframe(&game,
      to: .init(position: pose.position + pose.orientation.z * 200, orientation: facing))
    game.screen = .front
    game.speed = 0
    game.autoPilot.disengage()
    game.weaponsTargetID = body.id
    return unit.actor
  }

  func placeTenderAtActualPort(_ game: inout Game, depth: Double) throws {
    let state = try #require(game.glassMeridianMission?.savedGlassMeridian?.clinicEscort)
    let launch = try #require(state.current)
    let index = try #require(game.bodies.firstIndex {
      $0.missionActorID == NativeC01ClinicEscort.actor(mission: state.source.mission,
        ordinal: launch.ordinal)
    })
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let stationPose = game.modelPose(of: station)
    let port = MainStationGeometry.docking
    let normal = stationPose.orientation.apply(port.outward)
    let up = stationPose.orientation.apply(port.up)
    let entrance = stationPose.systemPoint(port.center)
    var inward = Basis3()
    inward.z = normal * -1
    inward.y = up
    inward.x = inward.y.cross(inward.z)
    // Controlled approach placement and velocity, not a berth receipt or completed mission.
    // The next real tick must still prove the moving port and every actual scene hull.
    NativeStationTestFixture.reframe(&game,
      to: .init(position: entrance + normal * 600, orientation: inward))
    let original = try NativeC01SurveyorGeometry.harrier.get()
    let ys = original.collision.vertices.map(\.y)
    let low = try #require(ys.min())
    let high = try #require(ys.max())
    let position = entrance - up * ((low + high) / 2) + normal * depth
    let velocity = (station.physical?.velocity ?? .init(0, 0, 0)) - normal * 30
    game.bodies[index].position = game.commander.flightSimulation.pose.shipPoint(position)
    game.bodies[index].orientation = inward.relative(to: game.commander.flightSimulation.pose.orientation)
    let localVelocity = game.commander.flightSimulation.pose.shipVector(velocity)
    game.bodies[index].scriptNPC?.velocity = localVelocity
    game.bodies[index].physical?.velocity = velocity
    game.screen = .front
    game.speed = 0
    game.autoPilot.disengage()
    game.persistScriptActors()
  }
}

extension NativeC01ClinicEscortUnitTests {
  @Test(arguments: [false, true])
  func actualParkedLaserFatalitySpendsOnlyThatUnitAndReserveIsFirstRealLaunch(
    _ refuseWriter: Bool
  ) async throws {
    let f = try await C01ClinicPeopleJourneyFixture()
    defer { f.clean() }
    var game = try await f.sourceGame()
    let frontID = try f.pointAtClinicStock(&game)
    let source = try #require(game.commander.nativePeople?.clinicSource)
    let missionID = try #require(game.glassMeridianMission?.id)
    let player = try #require(game.commander.flightSimulation.player)
    let reserveBefore = try #require(game.bodies.first { $0.missionActorID == source.unit(1)?.actor })
    let cash = game.commander.credits
    let kills = game.commander.kills
    let originalClues = game.commander.scriptState.savedClueJournal
    let standard = game.glassMeridianMission?.savedGlassMeridian?.timingStandard?.used
    let recorder = game.glassMeridianMission?.savedGlassMeridian?.surveyor?.capture?.operation
    // Advance only the real emission allocator. Misses/origins and combat incidents have
    // independent counters; the next genuine laser fatality must survive that divergence.
    let incidentCounterBefore = game.commander.flightSimulation.nextIncident
    let emissionLead = incidentCounterBefore + 1024
    while game.commander.flightSimulation.nextEmission < emissionLead {
      let emission = game.commander.flightSimulation.allocateEmission()
      try #require(emission != nil)
    }
    #expect(game.commander.flightSimulation.nextIncident == incidentCounterBefore)
    let before = try #require(game.c01ClinicAttainedSample())
    // Negative controls cannot mint a private fatal witness from rawzero or culling.
    var raw = game
    let rawIndex = try #require(raw.bodies.firstIndex { $0.missionActorID == frontID })
    raw.bodies[rawIndex].energy = 0
    raw.persistScriptActors()
    #expect(raw.c01ClinicFatalTransition(from: before, ordinal: 0) == nil)
    var culled = game
    let removed = culled.bodies.remove(at: rawIndex)
    culled.recordScriptActorRemoval(removed, destroyed: false)
    #expect(culled.c01ClinicFatalTransition(from: before, ordinal: 0) == nil)
    let runtime = GameRuntime(game: game, saveURL: f.save)
    try await runtime.save(to: f.save)
    let pointer = try Data(contentsOf: f.save)
    var fire = Controls()
    fire.fire = true
    await runtime.setControls(fire)
    var writerRefused = false
    for _ in 0..<1200 {
      let current = await runtime.snapshot()
      if current.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.loss(for: 0) != nil
        || current.c01ClinicEscortRuntime.pendingDeaths.contains(where: { $0.ordinal == 0 })
      { break }
      if refuseWriter && !writerRefused,
        let front = current.bodies.first(where: { $0.missionActorID == frontID }),
        front.energy > 0, front.energy < 100
      {
        try FileManager.default.removeItem(at: f.save)
        try FileManager.default.createDirectory(at: f.save, withIntermediateDirectories: false)
        writerRefused = true
      }
      _ = await runtime.advance(delta: 0.05)
    }
    await runtime.setControls(Controls())
    let fatal = await runtime.snapshot()
    if refuseWriter {
      try #require(writerRefused)
      let pending = try #require(fatal.c01ClinicEscortRuntime.pendingDeaths.first { $0.ordinal == 0 })
      #expect(pending.startTime < pending.physicalTime)
      let incident = try #require(pending.actor.body.physical?.deathIncidentID)
      #expect(incident >= pending.preNextIncident && incident < pending.postNextIncident)
      #expect(pending.actor.body.physical?.deathOrigin?.owner == player)
      #expect(fatal.commander.nativePeople?.clinicSource?.dispositions.isEmpty == true)
      #expect(fatal.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.parkedLosses.isEmpty == true)
      try FileManager.default.removeItem(at: f.save)
      try pointer.write(to: f.save, options: .atomic)
      // The real witness must remain usable after physical time advances on retry.
      _ = await runtime.advance(delta: 0.05)
    }
    let lost = await runtime.snapshot()
    let leaf = try #require(lost.glassMeridianMission?.savedGlassMeridian?.clinicEscort)
    let loss = try #require(leaf.loss(for: 0))
    let after = try #require(lost.commander.nativePeople?.clinicSource)
    let terminal = try #require(after.disposition(0))
    #expect(loss.launch == nil && leaf.launches.isEmpty && leaf.parkedLosses.count == 1)
    #expect(loss.sourceDisposition == terminal.operation && after.assignments.isEmpty)
    #expect(after.registration == source.registration && after.dispositions.count == 1)
    let fatalOrigin = try #require(loss.actor.body.physical?.deathOrigin)
    #expect(fatalOrigin.emissionID >= emissionLead)
    #expect(fatalOrigin.emissionID > lost.commander.flightSimulation.nextIncident)
    #expect(fatalOrigin.emissionID < lost.commander.flightSimulation.nextEmission)
    #expect(loss.actor.body.physical?.deathOrigin?.owner == player)
    #expect(lost.commander.kills == kills + 1 && lost.commander.legal > 0)
    #expect(lost.commander.credits == cash && lost.commander.scriptState.savedClueJournal == originalClues)
    #expect(lost.c01ClinicEscortRuntime.pendingDeaths.isEmpty && lost.commander.valid)
    #expect(lost.glassMeridianMission?.savedGlassMeridian?.timingStandard?.used == standard)
    #expect(lost.glassMeridianMission?.savedGlassMeridian?.surveyor?.capture?.operation == recorder)
    var positioned = lost
    try f.parkAtCradle(&positioned)
    let selected = GameRuntime(game: positioned, saveURL: f.save)
    try await selected.save(to: f.save)
    let beforeRelease = await selected.snapshot()
    await selected.key("return")
    let reviewing = await selected.snapshot()
    #expect(reviewing.c01ClinicEscortRuntime.review?.pilotName == "Daven Roh")
    await selected.key("return")
    let released = await selected.snapshot()
    let launch = try #require(released.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.current)
    #expect(launch.ordinal == 1 && launch.nativeActor == reserveBefore.physical?.identity)
    #expect(released.glassMeridianMission?.id == missionID)
    #expect(released.commander.nativePeople?.clinicSource?.assignments.count == 1)
    #expect(released.commander.nativePeople?.clinicSource?.dispositions.count == 1)
    #expect(released.bodies == beforeRelease.bodies)
    #expect(released.commander.flightSimulation == beforeRelease.commander.flightSimulation)
    #expect(released.nextBodyID == beforeRelease.nextBodyID && released.commander.credits == cash)
    #expect(released.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.arrival == nil)
    #expect(released.commander.valid)
  }

  @Test(arguments: [false, true])
  func actualNativePortReceivesOnceWriterReapproachesAndSpareFatalityPreservesArrival(
    _ refuseWriter: Bool
  ) async throws {
    let f = try await C01ClinicPeopleJourneyFixture()
    defer { f.clean() }
    var game = try await f.sourceGame()
    try f.parkAtCradle(&game)
    let launched = GameRuntime(game: game, saveURL: f.save)
    try await launched.save(to: f.save)
    await launched.key("return")
    await launched.key("return")
    game = await launched.snapshot()
    let launch = try #require(game.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.current)
    let sourceBefore = try #require(game.commander.nativePeople?.clinicSource)
    let originalCash = game.commander.credits
    let originalClues = game.commander.scriptState.savedClueJournal
    let originalRecorder = game.glassMeridianMission?.savedGlassMeridian?.surveyor?.capture?.operation
    let originalStandard = game.glassMeridianMission?.savedGlassMeridian?.timingStandard?.used
    // Controlled approach stays outside the port while actual native local-bubble
    // culling settles the distant cradle/reserve. It grants no arrival or stage progress.
    try f.placeTenderAtActualPort(&game, depth: 100)
    let approaching = GameRuntime(game: game, saveURL: f.save)
    try await approaching.save(to: f.save)
    for _ in 0..<3 { _ = await approaching.advance(delta: 0.05) }
    game = await approaching.snapshot()
    #expect(game.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.arrival == nil)
    try f.placeTenderAtActualPort(&game, depth: 1)
    let runtime = GameRuntime(game: game, saveURL: f.save)
    try await runtime.save(to: f.save)
    let before = await runtime.snapshot()
    let pointer = try Data(contentsOf: f.save)
    if refuseWriter {
      try FileManager.default.removeItem(at: f.save)
      try FileManager.default.createDirectory(at: f.save, withIntermediateDirectories: false)
    }
    _ = await runtime.advance(delta: 0.05)
    if refuseWriter {
      let refused = await runtime.snapshot()
      #expect(refused.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.arrival == nil)
      #expect(refused.commander.nativePeople?.clinicSource == sourceBefore)
      #expect(refused.glassMeridianMission?.receipts.contains(NativeC01ClinicEscort.receipt) == false)
      #expect(refused.bodies.contains { $0.missionActorID == NativeC01ClinicEscort.actor(
        mission: sourceBefore.registration.source.mission, ordinal: launch.ordinal) })
      try FileManager.default.removeItem(at: f.save)
      try pointer.write(to: f.save, options: .atomic)
    }
    for _ in 0..<400 {
      let current = await runtime.snapshot()
      if current.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.arrival != nil { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let received = await runtime.snapshot()
    let mission = try #require(received.glassMeridianMission)
    let leaf = try #require(mission.savedGlassMeridian?.clinicEscort)
    let arrival = try #require(leaf.arrival, Comment(rawValue: String(received.c01ClinicEscortRuntime.reason.prefix(160))))
    let source = try #require(received.commander.nativePeople?.clinicSource)
    let disposition = try #require(source.disposition(launch.ordinal))
    #expect(arrival.sequence > before.commander.scriptState.nextEvent)
    #expect(arrival.sequence <= received.commander.scriptState.nextEvent)
    #expect(arrival.launch == launch.operation && arrival.registeredHull == launch.registeredHull)
    #expect(arrival.pilot == launch.pilot && arrival.sourceReception == disposition.operation)
    #expect(arrival.physicalTime > arrival.startTime)
    #expect(arrival.physicalTime - arrival.startTime <= NativeC01LaneRepair.maximumPhysicalInterval)
    #expect(mission.hasAcknowledged(arrival.sequence) && mission.milestones == [0, 1, 2, 3, 4, 5, 6])
    #expect(mission.outcome == .active && mission.completionReceipt == nil)
    #expect(source.registration == sourceBefore.registration && source.assignments == sourceBefore.assignments)
    #expect(source.dispositions.count == 1 && received.commander.c01ClinicPilotFacts(for: launch)?.location
      == .receiver(leaf.source.station))
    #expect(!received.bodies.contains { $0.missionActorID == NativeC01ClinicEscort.actor(
      mission: mission.id, ordinal: launch.ordinal) })
    #expect(received.commander.credits == originalCash)
    #expect(received.commander.scriptState.savedClueJournal == originalClues)
    #expect(mission.savedGlassMeridian?.surveyor?.capture?.operation == originalRecorder)
    #expect(mission.savedGlassMeridian?.timingStandard?.used == originalStandard)
    #expect(received.commander.valid)
    let committedCounter = received.commander.scriptState.nextEvent
    var staleCounter = received.commander
    staleCounter.scriptState.nextEvent = arrival.sequence - 1
    let acceptsUnpublishedSequence = NativeC01ClinicEscortSave.physicalClaimsMatch(
      leaf, mission: mission, commander: staleCounter)
    #expect(!acceptsUnpublishedSequence)
    #expect(received.commander.scriptState.nextEvent == committedCounter)
    let sealed = source
    for _ in 0..<3 { _ = await runtime.advance(delta: 0.05) }
    let repeated = await runtime.snapshot()
    #expect(repeated.commander.nativePeople?.clinicSource == sealed)
    #expect(repeated.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.arrival == arrival)
    try await runtime.save(to: f.save)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: f.save)
    let loaded = await cold.snapshot()
    #expect(loaded.commander.nativePeople?.clinicSource == sealed && loaded.commander.valid)
    #expect(loaded.c01ClinicEscortRuntime.attainedSample == nil)
    #expect(loaded.c01ClinicEscortRuntime.pendingDeaths.isEmpty && loaded.c01ClinicEscortRuntime.controls.isEmpty)
    #expect(loaded.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.arrival == arrival)
    #expect(loaded.commander.credits == before.commander.credits)
    if !refuseWriter {
      var returning = loaded
      let remaining = try #require(loaded.glassMeridianMission?
        .ownedEncounters[NativeC01ClinicEscort.sourceEncounter]?
        .actors[NativeC01ClinicEscort.stockTarget(1)])
      let anchor = try #require(returning.scriptAnchor)
      let currentPose = returning.commander.flightSimulation.pose
      let sourcePoint = currentPose.systemPoint(
        anchor.position + anchor.orientation.apply(remaining.body.position))
      // Controlled player return uses the actual retained owner frame, then the existing
      // native restoration API rebinds the SAME logical spare with its retained condition.
      NativeStationTestFixture.reframe(&returning,
        to: .init(position: sourcePoint + .init(0, 0, 400)))
      try returning.restoreScriptActors()
      let spareID = try f.pointAtClinicStock(&returning, ordinal: 1)
      let spare = GameRuntime(game: returning, saveURL: f.save)
      try await spare.save(to: f.save)
      var fire = Controls()
      fire.fire = true
      await spare.setControls(fire)
      for _ in 0..<1200 {
        let current = await spare.snapshot()
        if current.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.loss(for: 1) != nil { break }
        _ = await spare.advance(delta: 0.05)
      }
      await spare.setControls(Controls())
      let late = await spare.snapshot()
      let lateLeaf = try #require(late.glassMeridianMission?.savedGlassMeridian?.clinicEscort)
      let lateLoss = try #require(lateLeaf.loss(for: 1))
      let lateSource = try #require(late.commander.nativePeople?.clinicSource)
      #expect(lateLoss.launch == nil && lateLoss.actor.identity == spareID)
      #expect(lateLoss.physicalTime > arrival.physicalTime)
      #expect(lateLoss.actor.body.physical?.deathIncidentID != nil)
      #expect(lateLeaf.arrival == arrival && lateLeaf.launches == leaf.launches)
      #expect(lateSource.registration == sealed.registration && lateSource.assignments == sealed.assignments)
      #expect(lateSource.dispositions.count == 2 && lateSource.disposition(launch.ordinal) == disposition)
      #expect(late.glassMeridianMission?.milestones == [0, 1, 2, 3, 4, 5, 6])
      #expect(late.commander.c01ClinicPilotFacts(for: launch)?.location == .receiver(leaf.source.station))
      #expect(late.commander.credits == originalCash && late.commander.scriptState.savedClueJournal == originalClues)
      #expect(late.commander.valid)
      try await spare.save(to: f.save)
      let afterLossLoad = GameRuntime(game: Game(executive: false))
      try await afterLossLoad.load(from: f.save)
      let final = await afterLossLoad.snapshot()
      #expect(final.commander.nativePeople?.clinicSource == lateSource && final.commander.valid)
      #expect(final.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.arrival == arrival)
      #expect(final.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.loss(for: 1) == lateLoss)
      #expect(final.c01ClinicEscortRuntime.pendingDeaths.isEmpty)
    }
  }
}

// Current receipt keys retain the ordinary mission local-ID contract.
extension NativeC01ClinicEscortUnitTests {
  @Test func clinicReceiptMarkersAreDistinctValidCurrentLocalIDs() {
    let markers = [NativeC01ClinicEscort.receipt, "escort-clinic", NativeC01ClinicEscort.target]
    let distinct = Set(markers).count
    #expect(distinct == 3)
    for marker in markers {
      let valid = PackValidation.localID(marker)
      #expect(valid)
    }
  }
}
