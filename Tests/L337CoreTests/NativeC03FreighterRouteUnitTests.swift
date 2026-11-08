import Foundation
import Testing

@testable import L337Core

/// Arithmetic/structural fixtures only. No C03 original, route admission or attained path is issued.
struct NativeC03FreighterRouteUnitTests {
  private typealias Route = NativeC03FreighterRoute
  private struct Fixture {
    var flight: FlightSimulationState
    var station: SpaceBody
    var body: SpaceBody
    var owned: ScriptOwnedActor
    var scheduler: Route.Scheduler
  }
  private func fixture() throws -> Fixture {
    let (game, mission, index) = try actualMissionBridgeGame()
    var body = game.bodies[index]
    let actor = try #require(body.missionActorID)
    var flight = FlightSimulationState()
    flight.enter(Route.world, arriving: false)
    let allocatedActor = flight.allocateActor()
    let physical = try #require(allocatedActor)
    let anchors = try #require(flight.anchors)
    let layout = try Route.candidateLayout(anchors: anchors)
    let binding = try Route.Binding(
      source: UUID(), mission: mission, sourceRevision: 1, actor: actor, actorAlias: "lead",
      physicalActor: physical, slot: .first, endpoints: layout.first)
    let scheduler = Route.Scheduler(binding: binding, target: .first)
    var station = SpaceBody(
      id: 0, hull: .station, position: flight.pose.shipPoint(anchors.station.position))
    station.physical = .init(identity: anchors.station.identity, population: .civilian)
    body.physical = .init(identity: physical, population: .mission)
    body.position = flight.pose.shipPoint(layout.first.first)
    body.orientation = .init()
    body.rotation = 0
    body.scriptNPC?.velocity = .init(0, 0, 0)
    let profile = try #require(body.scriptNPC?.fit.definition)
    let approach = try scheduler.approach(flight: flight, station: station, profile: profile)
    body.scriptNPC?.intent = .init(
      request: "route-fixture", mode: .approach, target: nil, player: false,
      offset: approach.offset, speed: approach.speedFraction, tolerance: approach.tolerance)
    let owned = ScriptOwnedActor(
      identity: actor, alias: binding.actorAlias, body: body, presence: .present)
    try #require(owned.valid)
    return .init(flight: flight, station: station, body: body, owned: owned, scheduler: scheduler)
  }
  private func arrived(_ fixture: inout Fixture, source: UUID? = nil, revision: UInt64? = nil)
    throws -> Bool
  {
    try fixture.scheduler.considerArrival(
      source: source ?? fixture.scheduler.binding.source,
      sourceRevision: revision ?? fixture.scheduler.binding.sourceRevision,
      owned: fixture.owned, body: fixture.body, flight: fixture.flight, station: fixture.station)
  }

  @Test func candidateUsesPlanetAwayNormalLeastAlignedAxisAndTwoFixedFiveHundredMetreLanes() throws
  {
    let f = try fixture()
    let a = try #require(f.flight.anchors)
    let layout = try Route.candidateLayout(anchors: a)
    #expect((layout.normal - (a.station.position - a.planet.position).unit).length < 1e-12)
    #expect(abs(layout.normal.dot(layout.u)) < 1e-12 && abs(layout.u.dot(layout.v)) < 1e-12)
    #expect((layout.normal.cross(layout.u) - layout.v).length < 1e-12)
    #expect((layout.u - Vector3(0, 1, 0).cross(layout.normal).unit).length < 1e-12)
    #expect(abs((layout.secondCentre - layout.firstCentre).length - 4000) < 1e-9)
    #expect(
      (layout.firstCentre - (a.station.position + layout.normal * 8000 - layout.u * 2000)).length
        < 1e-9)
    for (centre, endpoints) in [
      (layout.firstCentre, layout.first), (layout.secondCentre, layout.second),
    ] {
      #expect((endpoints.first - (centre - layout.v * 250)).length < 1e-9)
      #expect((endpoints.second - (centre + layout.v * 250)).length < 1e-9)
    }
  }

  @Test func axisTiesUseCartesianXYZAndDoNotUseSpinningStationAxes() throws {
    let f = try fixture()
    let a = try #require(f.flight.anchors)
    var spun = Basis3()
    spun.rotate(pitch: 0.3, roll: 0.8, yaw: 0.2)
    let input = SystemAnchors(
      system: Route.world,
      station: .init(
        identity: a.station.identity, position: .init(0, 0, 0), orientation: spun,
        exitPosition: a.station.exitPosition, exitDirection: a.station.exitDirection),
      arrival: a.arrival, planet: .init(position: .init(-1, -1, -1), radius: 1), sun: a.sun)
    let layout = try Route.candidateLayout(anchors: input)
    #expect((layout.u - Vector3(1, 0, 0).cross(layout.normal).unit).length < 1e-12)
  }

  @Test(arguments: [false, true])
  func offsetResolvesSameFrozenInertialGoalAfterPlayerMotionAndStationSpin(second: Bool) throws {
    var f = try fixture()
    if second { f.scheduler = .init(binding: f.scheduler.binding, target: .second) }
    let endpoint = f.scheduler.binding.endpoints.point(f.scheduler.target)
    let profile = try #require(f.body.scriptNPC?.fit.definition)
    f.flight.pose.position = .init(107, -311, 928)
    f.flight.pose.orientation.rotate(pitch: 0.47, roll: -0.33, yaw: 0.71)
    f.station.position = f.flight.pose.shipPoint(.init(43, 57, -91))
    f.station.orientation.rotate(pitch: -0.16, roll: 1.1, yaw: 0.28)
    f.station.rotation = 2.2
    let result = try f.scheduler.approach(flight: f.flight, station: f.station, profile: profile)
    let resolvedView = f.station.position + f.station.orientation.apply(result.offset)
    #expect((f.flight.pose.systemPoint(resolvedView) - endpoint).length < 1e-8)
    #expect(abs(profile.speed * result.speedFraction - 5) < 1e-12)
    #expect((0.0...1).contains(result.speedFraction) && result.tolerance == 5)
    #expect(f.scheduler.binding.endpoints.point(f.scheduler.target) == endpoint)
  }

  @Test func onlyActualSlowArrivalSwitchesAndRepeatedOldArrivalCannotSwitchAgain() throws {
    var f = try fixture()
    f.body.position.x += 5
    f.body.scriptNPC?.velocity = .init(0.999, 0, 0)
    f.body.physical?.velocity = .init(0.999, 0, 0)
    #expect(try arrived(&f))
    #expect(f.scheduler.target == .second)
    // Refresh the goal through the normal helper; the old body's first-endpoint position remains.
    let profile = try #require(f.body.scriptNPC?.fit.definition)
    let next = try f.scheduler.approach(flight: f.flight, station: f.station, profile: profile)
    f.body.scriptNPC?.intent = .init(
      request: "route-fixture-next", mode: .approach, target: nil,
      player: false, offset: next.offset, speed: next.speedFraction, tolerance: next.tolerance)
    #expect(try !arrived(&f))
    #expect(f.scheduler.target == .second)
    // Fixture placement of the second observed arrival is not an executed flight claim.
    f.body.position = f.flight.pose.shipPoint(f.scheduler.binding.endpoints.second)
    #expect(try arrived(&f))
    #expect(f.scheduler.target == .first)
  }

  @Test(arguments: ["fast", "far"])
  func timerOrReachedStatusDoesNotReplacePositionAndSpeed(reason: String) throws {
    var f = try fixture()
    f.flight.advancePhysicalTime(100000)
    f.body.scriptNPC?.intent?.status = .reached
    if reason == "fast" {
      f.body.scriptNPC?.velocity = .init(1, 0, 0)
      f.body.physical?.velocity = .init(1, 0, 0)
    } else {
      f.body.position.x += 5.001
    }
    #expect(try !arrived(&f))
    #expect(f.scheduler.target == .first)
  }

  @Test(arguments: [
    "source", "revision", "owned", "actor", "physical", "world", "visit", "intent", "lost", "fit",
    "velocity",
  ])
  func staleOrForeignStructuralJoinsRefuseWithoutChangingTarget(reason: String) throws {
    var f = try fixture()
    var source = f.scheduler.binding.source
    var revision = f.scheduler.binding.sourceRevision
    switch reason {
    case "source": source = UUID()
    case "revision": revision += 1
    case "owned": f.owned.presence = .unloaded
    case "actor": f.body.missionActorID = UUID()
    case "physical":
      let invalidPhysicalActor = f.flight.allocateActor()
      f.body.physical = .init(
        identity: try #require(invalidPhysicalActor), population: .mission)
    case "world": f.flight.enter(.init(galaxy: 0, system: 7), arriving: false)
    case "visit": f.flight.enter(Route.world, arriving: false)
    case "intent": f.body.scriptNPC?.intent = nil
    case "lost": f.body.scriptNPC?.intent?.status = .lost
    case "fit": f.owned.body.scriptNPC = nil
    default: f.body.physical?.velocity = .init(0.01, 0, 0)
    }
    #expect(throws: Route.Failure.self) { try arrived(&f, source: source, revision: revision) }
    #expect(f.scheduler.target == .first)
  }

  @Test(arguments: ["missing", "reflected", "scaled", "nonfinite"])
  func missingOrImproperCurrentFramesRefuse(reason: String) throws {
    var f = try fixture()
    let profile = try #require(f.body.scriptNPC?.fit.definition)
    if reason == "reflected" { f.station.orientation.x = .init(-1, 0, 0) }
    if reason == "scaled" { f.flight.pose.orientation.y = .init(0, 2, 0) }
    if reason == "nonfinite" { f.station.position.x = .nan }
    #expect(throws: Route.Failure.self) {
      try f.scheduler.approach(
        flight: f.flight, station: reason == "missing" ? nil : f.station, profile: profile)
    }
  }

  @Test(arguments: ["speed", "acceleration"])
  func incompatibleActualNativeProfileCannotBeTreatedAsFiveMetresPerSecond(field: String) throws {
    let f = try fixture()
    let profile = try #require(f.body.scriptNPC?.fit.definition)
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
    fields[field] = field == "speed" ? 4.0 : 0.0
    let changed = try JSONDecoder().decode(
      ScriptNPCDefinition.self, from: JSONSerialization.data(withJSONObject: fields))
    #expect(throws: Route.Failure.self) {
      try f.scheduler.approach(flight: f.flight, station: f.station, profile: changed)
    }
  }

  @Test func invalidCandidateAndEndpointsRefuseWithoutAllocatingOrResettingAnything() throws {
    let f = try fixture()
    let before = f.flight
    #expect(throws: Route.Failure.self) { try Route.candidateLayout(anchors: nil) }
    #expect(throws: Route.Failure.self) {
      try Route.Endpoints(first: .init(0, 0, 0), second: .init(0, 0, 0))
    }
    #expect(throws: Route.Failure.self) {
      try Route.Endpoints(first: .init(.nan, 0, 0), second: .init(0, 0, 500))
    }
    let a = try #require(f.flight.anchors)
    let invalid = SystemAnchors(
      system: a.system, station: a.station, arrival: a.arrival,
      planet: .init(position: a.station.position, radius: a.planet.radius), sun: a.sun)
    #expect(throws: Route.Failure.self) { try Route.candidateLayout(anchors: invalid) }
    #expect(f.flight == before)
  }
}
