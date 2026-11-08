import Foundation

/// Unwired C03 route arithmetic. Caller data/structural joins are not native source authority.
enum NativeC03FreighterRoute {
  static let world = SystemIdentity(galaxy: 1, system: 113)
  static let speedMetresPerSecond = 5.0
  static let arrivalTolerance = 5.0
  enum Failure: Error {
    case invalidAnchors, invalidEndpoints, invalidFrame, invalidProfile, invalidJoin
  }
  enum Slot: String, CaseIterable, Sendable {
    case first = "freighter-seal-a"
    case second = "freighter-seal-b"
  }
  enum Waypoint: Sendable, Equatable {
    case first, second
    var next: Self { self == .first ? .second : .first }
  }
  struct Endpoints: Sendable, Equatable {
    let first: Vector3
    let second: Vector3
    init(first: Vector3, second: Vector3) throws {
      guard NativeC03FreighterRoute.finite(first), NativeC03FreighterRoute.finite(second),
        abs((second - first).length - 500) <= 1e-6
      else {
        throw Failure.invalidEndpoints
      }
      self.first = first
      self.second = second
    }
    func point(_ waypoint: Waypoint) -> Vector3 { waypoint == .first ? first : second }
  }
  struct Layout: Sendable {
    let normal: Vector3
    let u: Vector3
    let v: Vector3
    let firstCentre: Vector3
    let secondCentre: Vector3
    let first: Endpoints
    let second: Endpoints
  }

  /// Proposed first-source layout only. Never call to reset a live/cull-restored source.
  static func candidateLayout(anchors: SystemAnchors?) throws -> Layout {
    guard let anchors, anchors.system == world, anchors.station.identity.system == world,
      anchors.station.identity.entity == 1, anchors.station.identity.visit > 0,
      finite(anchors.station.position), finite(anchors.planet.position),
      finite(anchors.sun.position), finite(anchors.arrival), finite(anchors.station.exitPosition),
      finite(anchors.station.exitDirection), proper(anchors.station.orientation),
      anchors.planet.radius.isFinite, anchors.planet.radius > 0,
      anchors.sun.radius.isFinite, anchors.sun.radius > 0
    else { throw Failure.invalidAnchors }
    let delta = anchors.station.position - anchors.planet.position
    guard finite(delta), delta.length > 1e-9 else { throw Failure.invalidAnchors }
    let n = delta.unit
    // Strict comparison preserves the explicit X,Y,Z tie order.
    var cartesian = Vector3(1, 0, 0)
    for axis in [Vector3(0, 1, 0), Vector3(0, 0, 1)] {
      if abs(axis.dot(n)) < abs(cartesian.dot(n)) { cartesian = axis }
    }
    let u = cartesian.cross(n).unit
    let v = n.cross(u)
    let centre = anchors.station.position + n * 8000
    let first = centre - u * 2000
    let second = centre + u * 2000
    return .init(
      normal: n, u: u, v: v, firstCentre: first, secondCentre: second,
      first: try .init(first: first - v * 250, second: first + v * 250),
      second: try .init(first: second - v * 250, second: second + v * 250))
  }

  /// Explicit references to an already source-owned route and its actually allocated actor.
  /// Construction proves no issuance, admission, original identity or live observation.
  struct Binding: Sendable {
    let source: UUID
    let mission: UUID
    let sourceRevision: UInt64
    let actor: UUID
    let actorAlias: String
    let physicalActor: ActorIdentity
    let slot: Slot
    let endpoints: Endpoints
    init(
      source: UUID, mission: UUID, sourceRevision: UInt64, actor: UUID, actorAlias: String,
      physicalActor: ActorIdentity,
      slot: Slot, endpoints: Endpoints
    ) throws {
      guard physicalActor.system == NativeC03FreighterRoute.world, physicalActor.visit > 0,
        physicalActor.entity > 1,
        sourceRevision > 0, sourceRevision < UInt64.max, PackValidation.localID(actorAlias)
      else {
        throw Failure.invalidJoin
      }
      self.source = source
      self.mission = mission
      self.sourceRevision = sourceRevision
      self.actor = actor
      self.actorAlias = actorAlias
      self.physicalActor = physicalActor
      self.slot = slot
      self.endpoints = endpoints
    }
  }

  struct Approach: Sendable {
    let offset: Vector3
    let speedFraction: Double
    let tolerance: Double
  }

  struct Scheduler: Sendable {
    let binding: Binding
    // No default target: the actual source/retained state must supply it explicitly.
    private(set) var target: Waypoint

    /// Inverse of ScriptNPCFlight's station.position + station.orientation.apply(offset).
    func approach(
      flight: FlightSimulationState, station: SpaceBody?, profile: ScriptNPCDefinition
    ) throws -> Approach {
      let station = try NativeC03FreighterRoute.currentStation(
        flight: flight, station: station, binding: binding)
      guard profile.valid, profile.speed >= NativeC03FreighterRoute.speedMetresPerSecond,
        profile.acceleration > 0
      else {
        throw Failure.invalidProfile
      }
      let goal = flight.pose.shipPoint(binding.endpoints.point(target))
      let offset = station.orientation.transposed.apply(goal - station.position)
      guard NativeC03FreighterRoute.finite(offset), offset.length <= 1_000_000 else {
        throw Failure.invalidFrame
      }
      return .init(
        offset: offset, speedFraction: NativeC03FreighterRoute.speedMetresPerSecond / profile.speed,
        tolerance: NativeC03FreighterRoute.arrivalTolerance)
    }

    /// Structural reducer over supplied live records; never consumes a timer/event receipt.
    /// The future runtime must join `source` to G2's actual original before calling this.
    mutating func considerArrival(
      source: UUID, sourceRevision: UInt64, owned: ScriptOwnedActor?, body: SpaceBody?,
      flight: FlightSimulationState, station: SpaceBody?
    ) throws -> Bool {
      let station = try NativeC03FreighterRoute.currentStation(
        flight: flight, station: station, binding: binding)
      guard source == binding.source, sourceRevision == binding.sourceRevision, let owned, let body,
        owned.valid,
        owned.presence == .present, owned.alias == binding.actorAlias,
        owned.identity == binding.actor, body.missionActorID == binding.actor,
        body.missionInstanceID == binding.mission, owned.body.missionActorID == binding.actor,
        owned.body.missionInstanceID == binding.mission, owned.body.id == body.id,
        owned.body.physical?.identity == binding.physicalActor,
        let physical = body.physical, physical.identity == binding.physicalActor,
        physical.population == .mission, body.energy.isFinite, body.energy > 0,
        NativeC03FreighterRoute.finite(body.position),
        NativeC03FreighterRoute.proper(body.orientation), body.rotation.isFinite,
        let npc = body.scriptNPC, npc.valid, owned.body.scriptNPC?.fit == npc.fit,
        npc.fit.definition.acceleration > 0, NativeC03FreighterRoute.finite(physical.velocity),
        let intent = npc.intent, intent.mode == .approach, intent.target == nil, !intent.player,
        intent.valid, intent.status != .lost,
        intent.tolerance == NativeC03FreighterRoute.arrivalTolerance,
        abs(npc.fit.definition.speed * intent.speed - NativeC03FreighterRoute.speedMetresPerSecond)
          < 1e-9
      else { throw Failure.invalidJoin }
      let endpoint = binding.endpoints.point(target)
      let resolved = station.position + station.orientation.apply(intent.offset)
      let goal = flight.pose.shipPoint(endpoint)
      let worldVelocity = flight.pose.orientation.apply(npc.velocity)
      // Match the actual current intent and the post-flight physical velocity synchronization.
      guard NativeC03FreighterRoute.finite(resolved), (resolved - goal).length <= 1e-7,
        (worldVelocity - physical.velocity).length <= 1e-7
      else { throw Failure.invalidJoin }
      let position = flight.pose.systemPoint(body.position)
      guard NativeC03FreighterRoute.finite(position) else { throw Failure.invalidJoin }
      guard (position - endpoint).length <= NativeC03FreighterRoute.arrivalTolerance,
        worldVelocity.length < 1
      else {
        return false
      }
      target = target.next
      return true
    }
  }

  private static func currentStation(
    flight: FlightSimulationState, station: SpaceBody?, binding: Binding
  ) throws -> SpaceBody {
    guard flight.valid, flight.system == world, let player = flight.player,
      player.visit == binding.physicalActor.visit, let anchors = flight.anchors,
      anchors.system == world, anchors.station.identity.system == world,
      anchors.station.identity.entity == 1, anchors.station.identity.visit == player.visit,
      finite(anchors.station.position), proper(anchors.station.orientation),
      finite(flight.pose.position), proper(flight.pose.orientation), let station,
      station.id == 0, station.hull == .station, station.energy.isFinite, station.energy > 0,
      station.physical?.identity == anchors.station.identity,
      finite(station.position), proper(station.orientation), station.rotation.isFinite
    else { throw Failure.invalidFrame }
    return station
  }
  private static func finite(_ value: Vector3) -> Bool { value.finite && value.length.isFinite }
  private static func proper(_ basis: Basis3) -> Bool {
    [basis.x, basis.y, basis.z].allSatisfy({ finite($0) && abs($0.length - 1) < 1e-9 })
      && abs(basis.x.dot(basis.y)) < 1e-9 && abs(basis.x.dot(basis.z)) < 1e-9
      && abs(basis.y.dot(basis.z)) < 1e-9 && basis.x.cross(basis.y).dot(basis.z) > 1 - 1e-9
  }
}
