import Foundation

/// Authored collision tuning, not catalogue specifications or a conversion of render radii.
enum AsteroidImpactPolicy {
  static let restitution = 0.15
  static let metresPerCollisionUnit = 1.0
  static let joulesPerEnergy = 10_000.0
  static let maximumSpeed = 100_000.0
  static let maximumCandidatePairs = 32

  static func massKg(hull: Hull) -> Double {
    switch hull {
    case .station: 1_000_000_000
    case .cobra, .constrictor, .thargoid: 100_000
    case .viper: 45_000
    case .sidewinder, .thargon: 25_000
    case .cargo: 1000
    case .asteroid: 50_000
    case .missile: 250
    }
  }

  static func impulse(
    sourceMass: Double, targetMass: Double, sourceVelocity: Vector3,
    targetVelocity: Vector3, normal: Vector3
  ) -> AsteroidImpulse? {
    guard sourceMass.isFinite, targetMass.isFinite,
      (0.001...1e12).contains(sourceMass), (0.001...1e12).contains(targetMass),
      sourceVelocity.finite, targetVelocity.finite,
      sourceVelocity.length <= maximumSpeed, targetVelocity.length <= maximumSpeed,
      normal.finite, abs(normal.length - 1) < 1e-6
    else { return nil }
    let closing = (sourceVelocity - targetVelocity).dot(normal)
    guard closing.isFinite, closing > 1e-8 else { return nil }
    let inverseMass = 1 / sourceMass + 1 / targetMass
    let magnitude = (1 + restitution) * closing / inverseMass
    let impulse = normal * magnitude
    let a = sourceVelocity - impulse * (1 / sourceMass)
    let b = targetVelocity + impulse * (1 / targetMass)
    let loss =
      0.5 / inverseMass * (1 - restitution * restitution)
      * pow(closing * metresPerCollisionUnit, 2)
    let damage = loss / joulesPerEnergy
    guard a.finite, b.finite, a.length <= maximumSpeed, b.length <= maximumSpeed,
      impulse.finite, impulse.length.isFinite, damage.isFinite, (0...1e12).contains(damage)
    else { return nil }
    return .init(source: a, target: b, transferred: impulse, damage: damage)
  }

  /// Resolve the cone of already certified material faces together. Restitution
  /// is bounded by the authored value and cannot push either body back into a
  /// previous face or add kinetic energy at a corner.
  static func impulse(
    sourceMass: Double, targetMass: Double, sourceVelocity: Vector3,
    targetVelocity: Vector3, normals: [Vector3]
  ) -> AsteroidImpulse? {
    guard sourceMass.isFinite, targetMass.isFinite,
      (0.001...1e12).contains(sourceMass), (0.001...1e12).contains(targetMass),
      sourceVelocity.finite, targetVelocity.finite,
      sourceVelocity.length <= maximumSpeed, targetVelocity.length <= maximumSpeed,
      !normals.isEmpty, normals.count <= maximumCandidatePairs,
      normals.allSatisfy({ $0.finite && abs($0.length - 1) < 1e-6 })
    else { return nil }
    if normals.count == 1 {
      return impulse(
        sourceMass: sourceMass, targetMass: targetMass,
        sourceVelocity: sourceVelocity, targetVelocity: targetVelocity, normal: normals[0])
    }
    let relative = sourceVelocity - targetVelocity
    let numerical = 1e-12 * max(1, relative.length)
    var correction: Vector3?
    func consider(_ candidate: Vector3, multipliers: [Double]) {
      guard candidate.finite, multipliers.allSatisfy({ $0.isFinite && $0 >= 0 }),
        normals.allSatisfy({ (relative - candidate).dot($0) <= numerical })
      else { return }
      if correction == nil || candidate.dot(candidate) < correction!.dot(correction!) {
        correction = candidate
      }
    }
    consider(.init(0, 0, 0), multipliers: [])
    for i in normals.indices {
      let a = normals[i]
      let c = relative.dot(a) / a.dot(a)
      consider(a * c, multipliers: [c])
      for j in normals.indices where j > i {
        let b = normals[j]
        let aa = a.dot(a)
        let ab = a.dot(b)
        let bb = b.dot(b)
        let determinant = aa * bb - ab * ab
        if determinant > 1e-12 {
          let x = (relative.dot(a) * bb - relative.dot(b) * ab) / determinant
          let y = (relative.dot(b) * aa - relative.dot(a) * ab) / determinant
          consider(a * x + b * y, multipliers: [x, y])
        }
        for k in normals.indices where k > j {
          let c = normals[k]
          let determinant = a.dot(b.cross(c))
          guard abs(determinant) > 1e-12 else { continue }
          let x = relative.dot(b.cross(c)) / determinant
          let y = a.dot(relative.cross(c)) / determinant
          let z = a.dot(b.cross(relative)) / determinant
          consider(relative, multipliers: [x, y, z])
        }
      }
    }
    guard let correction else { return nil }
    let projected = relative - correction
    var bounce = restitution
    for normal in normals {
      let rebound = -correction.dot(normal)
      if rebound > 0 { bounce = min(bounce, max(0, -projected.dot(normal) / rebound)) }
    }
    let outgoing = projected - correction * bounce
    guard outgoing.finite, outgoing.dot(outgoing) <= relative.dot(relative) + numerical,
      normals.allSatisfy({ outgoing.dot($0) <= numerical })
    else { return nil }
    let inverseMass = 1 / sourceMass + 1 / targetMass
    let transfer = (relative - outgoing) * (1 / inverseMass)
    let a = sourceVelocity - transfer * (1 / sourceMass)
    let b = targetVelocity + transfer * (1 / targetMass)
    let damage =
      max(0, relative.dot(relative) - outgoing.dot(outgoing))
      * (0.5 / inverseMass * metresPerCollisionUnit * metresPerCollisionUnit / joulesPerEnergy)
    guard a.finite, b.finite, a.length <= maximumSpeed, b.length <= maximumSpeed,
      transfer.finite, damage.isFinite, (0...1e12).contains(damage)
    else { return nil }
    return .init(source: a, target: b, transferred: transfer, damage: damage)
  }
}

struct AsteroidImpulse: Sendable {
  let source: Vector3
  let target: Vector3
  let transferred: Vector3
  let damage: Double
}

/// Only the live producer in this file constructs a receipt after a real accepted effect.
struct AsteroidImpactReceipt: Sendable {
  let source: ActorIdentity
  let target: ActorIdentity
  let point: Vector3
  let transferredMomentum: Vector3
  let damage: Double
  let incident: UInt64
  let contactPhysicalTime: Double
  let clockEffect: NativeDebrisImpactClockEffect?
  fileprivate init(
    source: ActorIdentity, target: ActorIdentity, point: Vector3,
    transferredMomentum: Vector3, damage: Double, incident: UInt64, contactPhysicalTime: Double,
    clockEffect: NativeDebrisImpactClockEffect? = nil
  ) {
    self.source = source
    self.target = target
    self.point = point
    self.transferredMomentum = transferredMomentum
    self.damage = damage
    self.incident = incident
    self.contactPhysicalTime = contactPhysicalTime
    self.clockEffect = clockEffect
  }
}

final class NativeDebrisImpactClockEffect: Sendable {
  private let opening: FlightSimulationState
  private let playerPose: ShipPose
  private let hit: NativeCombatHitClockEffect

  fileprivate init(
    opening: FlightSimulationState, playerPose: ShipPose,
    hit: NativeCombatHitClockEffect
  ) {
    self.opening = opening
    self.playerPose = playerPose
    self.hit = hit
  }

  func applying(to before: FlightSimulationState) -> FlightSimulationState? {
    guard before == opening else { return nil }
    var expected = before
    expected.pose = playerPose
    guard expected.allocateEmission() == hit.incident.origin.emissionID else { return nil }
    return hit.applying(to: expected)
  }
}

enum AsteroidContactStepResult {
  case advanced(AsteroidImpactReceipt?)
  case refused(String)
  var admitted: Bool {
    if case .advanced = self { return true }
    return false
  }
}

/// Only the live contact producer can construct this non-decodable station transfer.
struct StationContactTransfer: Sendable {
  let station: StationInertialIdentity
  let actor: ActorIdentity
  let bodyID: Int
  let system: SystemIdentity
  let visit: UInt64
  let physicalTime: Double
  let impactTime: Double
  let previousVelocity: Vector3
  let finalPosition: Vector3
  let finalVelocity: Vector3
  let impulse: Vector3
  let damage: Double
  fileprivate init(
    station: StationInertialIdentity, actor: ActorIdentity, bodyID: Int,
    system: SystemIdentity, visit: UInt64, physicalTime: Double, impactTime: Double,
    previousVelocity: Vector3,
    finalPosition: Vector3, finalVelocity: Vector3, impulse: Vector3, damage: Double
  ) {
    self.station = station
    self.actor = actor
    self.bodyID = bodyID
    self.system = system
    self.visit = visit
    self.physicalTime = physicalTime
    self.impactTime = impactTime
    self.previousVelocity = previousVelocity
    self.finalPosition = finalPosition
    self.finalVelocity = finalVelocity
    self.impulse = impulse
    self.damage = damage
  }
}

/// Refused movement is a clock-bound rollback, never an admitted impact.
struct StationMotionRefusal: Sendable {
  let station: StationInertialIdentity
  let actor: ActorIdentity
  let bodyID: Int
  let system: SystemIdentity
  let visit: UInt64
  let fromTime: Double
  let toTime: Double
  let duration: Double
  let position: Vector3
  let velocity: Vector3
  fileprivate init(
    station: StationInertialIdentity, actor: ActorIdentity, bodyID: Int,
    system: SystemIdentity, visit: UInt64, fromTime: Double, toTime: Double, duration: Double,
    position: Vector3, velocity: Vector3
  ) {
    self.station = station
    self.actor = actor
    self.bodyID = bodyID
    self.system = system
    self.visit = visit
    self.fromTime = fromTime
    self.toTime = toTime
    self.duration = duration
    self.position = position
    self.velocity = velocity
  }
}

private struct DebrisActorFrame {
  let identity: ActorIdentity
  let bodyID: Int?
  let pose: ShipPose
  let velocity: Vector3
  let mesh: Mesh
  let mass: Double
  let debris: Bool
  let asteroid: Bool
  let station: StationInertialIdentity?
  let hull: Hull
  let localOrientation: Basis3
  let rotation: Double
}

private struct DebrisBodyMotion {
  let id: Int
  let identity: ActorIdentity?
  let position: Vector3
  let orientation: Basis3
  let rotation: Double
  let velocity: Vector3?
  let npcViewVelocity: Vector3?
  let shotViewVelocity: Vector3?
}

/// Captured only by this source file from the actual pre-movement owner state.
/// No decoder or caller-created expected set can construct this value.
struct NativeStationRefusalCohort {
  enum Source: Equatable {
    case original(NativeStationRecord, NativeStationSavedPose, NativeStationSourceBinding)
    case main(NativeMainStationIdentity, ScriptStationResource)
  }
  struct Member {
    let station: StationInertialIdentity
    let actor: ActorIdentity
    let bodyID: Int
    let pose: ShipPose
    let velocity: Vector3
    let prior: NativeStationInertia?
    let source: Source
    fileprivate init(station: StationInertialIdentity, actor: ActorIdentity, bodyID: Int,
      pose: ShipPose, velocity: Vector3, prior: NativeStationInertia?, source: Source)
    {
      self.station = station
      self.actor = actor
      self.bodyID = bodyID
      self.pose = pose
      self.velocity = velocity
      self.prior = prior
      self.source = source
    }
  }
  let owner: UUID
  let world: UUID?
  let adapterRevision: String?
  let geometryRevision: String?
  let system: SystemIdentity
  let visit: UInt64
  let player: ActorIdentity
  let playerPose: ShipPose
  let epoch: UUID
  let captureRevision: UInt64
  let start: Double
  let end: Double
  let usedDuration: Double
  let members: [Member]
  private let mainHadInertia: Bool

  fileprivate init?(capturing game: borrowing Game, start: Double, end: Double,
    usedDuration: Double, stationReady: Bool)
  {
    guard stationReady, usedDuration.isFinite, usedDuration > 0, usedDuration <= 0.1,
      start.isFinite, end.isFinite, start >= 0, end > start,
      start == end - usedDuration, end == game.storedFlightSimulation().physicalTime,
      let owner = game.commander.equipmentOwnerID,
      let player = game.storedFlightSimulation().player,
      player.system == game.systemIdentity, player.visit == game.storedFlightSimulation().visit,
      !game.docked, game.pendingNativeStationDock == nil
    else { return nil }
    self.owner = owner
    let system = game.systemIdentity
    self.system = system
    visit = game.storedFlightSimulation().visit
    self.player = player
    playerPose = game.storedFlightSimulation().pose
    epoch = game.nativeStationRuntimeEpoch
    captureRevision = game.gameplayRevision
    self.start = start
    self.end = end
    self.usedDuration = usedDuration
    var captured: [Member] = []
    guard let sourceWorld = game.storedNativeStationWorld() else {
      // A missing required original world is not an empty cohort.
      guard !OriginalStationSite.allCases.contains(where: { $0.system == system }),
        !game.bodies.contains(where: { $0.nativeStationIdentity != nil }),
        game.nativeStationDockEvidence == nil, game.nativeMainStationDockEvidence == nil,
        game.commander.nativeUtility == nil, game.commander.nativePeople?.utilityEngineer == nil,
        Self.hasNoWorldClaims(game),
        game.commander.valid
      else { return nil }
      world = nil
      adapterRevision = nil
      geometryRevision = nil
      mainHadInertia = false
      members = []
      return
    }
    guard sourceWorld.valid, sourceWorld.ledger.world == owner else { return nil }
    world = sourceWorld.ledger.world
    adapterRevision = sourceWorld.adapterRevision
    geometryRevision = sourceWorld.geometryRevision
    let expected = sourceWorld.ledger.records.filter {
      $0.identity.system == system && $0.tombstone == nil
    }
    let actual = game.bodies.filter { $0.nativeStationIdentity != nil }
    guard actual.count == expected.count,
      Set(actual.compactMap(\.nativeStationIdentity)) == Set(expected.map(\.identity))
    else { return nil }
    for record in expected {
      guard NativeStationSource.authentic(record, owner: owner),
        let source = NativeStationSource.binding(for: record.identity),
        let saved = sourceWorld.pose(for: record.identity),
        let body = actual.first(where: { $0.nativeStationIdentity == record.identity }),
        let physical = body.physical, body.energy == saved.energy, body.energy > 0,
        record.binding == .init(actor: physical.identity, bodyID: body.id),
        physical.identity.system == system, physical.identity.visit == visit,
        physical.catalogueShipID == source.catalogueShipID,
        physical.ordnance == nil, body.scriptShot == nil,
        sourceWorld.bodyRigidPoseIsConsistent(body, flight: game.storedFlightSimulation(), at: start)
      else { return nil }
      let station = StationInertialIdentity.originalStation(record.identity)
      let prior = sourceWorld.inertia(for: station)
      guard prior == nil || (prior?.valid == true && prior!.physicalTime <= start) else { return nil }
      captured.append(.init(station: station, actor: physical.identity, bodyID: body.id,
        pose: game.modelPose(of: body), velocity: physical.velocity, prior: prior,
        source: .original(record, saved, source)))
    }
    if let identity = sourceWorld.mainStations.first(where: { $0.system == system }),
      let prior = sourceWorld.inertia(for: .main(identity))
    {
      guard identity.world == owner, prior.valid, prior.physicalTime <= start,
        let body = game.bodies.first(where: { $0.id == 0 }),
        game.bodies.filter({ $0.id == 0 }).count == 1,
        let physical = body.physical, let anchors = game.storedFlightSimulation().anchors,
        physical.identity == anchors.station.identity, physical.identity.system == system,
        physical.identity.visit == visit, body.hull == .station, body.energy > 0,
        let resource = game.storedNativeStationResource(for: identity.key),
        resource.identity == identity.resource, !resource.destroyed,
        let position = sourceWorld.currentPosition(for: .main(identity), at: start),
        (playerPose.systemPoint(body.position) - position).length < 1e-5,
        (physical.velocity - prior.velocity).length < 1e-7
      else { return nil }
      mainHadInertia = true
      captured.append(.init(station: .main(identity), actor: physical.identity, bodyID: body.id,
        pose: game.modelPose(of: body), velocity: physical.velocity, prior: prior,
        source: .main(identity, resource)))
    } else {
      mainHadInertia = false
    }
    guard Set(captured.map(\.station)).count == captured.count,
      Set(captured.map(\.actor)).count == captured.count,
      Set(captured.map(\.bodyID)).count == captured.count
    else { return nil }
    members = captured
  }

  /// Validate restored bindings against the independently captured complete membership.
  func matchesRestored(_ game: borrowing Game) -> Bool {
    guard owner == game.commander.equipmentOwnerID, system == game.systemIdentity,
      visit == game.storedFlightSimulation().visit, player == game.storedFlightSimulation().player,
      epoch == game.nativeStationRuntimeEpoch, captureRevision == game.gameplayRevision,
      end == game.storedFlightSimulation().physicalTime,
      playerPose == game.storedFlightSimulation().pose, start == end - usedDuration,
      usedDuration.isFinite, usedDuration > 0, usedDuration <= 0.1, end > start
    else { return false }
    guard let expectedWorld = world else {
      return members.isEmpty && !mainHadInertia && game.storedNativeStationWorld() == nil
        && !OriginalStationSite.allCases.contains(where: { $0.system == system })
        && !game.bodies.contains(where: { $0.nativeStationIdentity != nil })
        && game.nativeStationDockEvidence == nil && game.nativeMainStationDockEvidence == nil
        && game.commander.nativeUtility == nil && game.commander.nativePeople?.utilityEngineer == nil
        && Self.hasNoWorldClaims(game)
        && game.commander.valid
    }
    guard let current = game.storedNativeStationWorld(), current.valid,
      current.ledger.world == expectedWorld, current.adapterRevision == adapterRevision,
      current.geometryRevision == geometryRevision
    else { return false }
    let currentOriginals = current.ledger.records.filter { $0.identity.system == system && $0.tombstone == nil }
    let capturedOriginals = members.compactMap { member -> NativeStationIdentity? in
      if case .originalStation(let id) = member.station { return id }
      return nil
    }
    let actual = game.bodies.filter { $0.nativeStationIdentity != nil }
    guard Set(currentOriginals.map(\.identity)) == Set(capturedOriginals),
      actual.count == capturedOriginals.count,
      Set(actual.compactMap(\.nativeStationIdentity)) == Set(capturedOriginals)
    else { return false }
    let currentMain = current.mainStations.first(where: { $0.system == system })
    let nowHasMain = currentMain.map { current.inertia(for: .main($0)) != nil } ?? false
    guard nowHasMain == mainHadInertia else { return false }
    for member in members {
      guard let body = game.bodies.first(where: { $0.id == member.bodyID }),
        game.bodies.filter({ $0.id == member.bodyID }).count == 1,
        let physical = body.physical, physical.identity == member.actor,
        physical.identity.system == system, physical.identity.visit == visit,
        body.energy > 0, physical.ordnance == nil,
        (playerPose.systemPoint(body.position) - member.pose.position).length < 1e-5,
        (physical.velocity - member.velocity).length < 1e-7
      else { return false }
      switch member.source {
      case .original(let record, let saved, let binding):
        guard current.ledger.records.first(where: { $0.identity == record.identity }) == record,
          current.pose(for: record.identity) == saved,
          NativeStationSource.binding(for: record.identity) == binding,
          body.nativeStationIdentity == record.identity,
          current.bodyRigidPoseIsConsistent(body, flight: game.storedFlightSimulation(), at: start)
        else { return false }
      case .main(let id, let resource):
        guard currentMain == id, current.mainStations.contains(id), body.id == 0,
          game.storedNativeStationResource(for: id.key) == resource, !resource.destroyed,
          game.storedFlightSimulation().anchors?.station.identity == physical.identity,
          let point = current.currentPosition(for: .main(id), at: start),
          (playerPose.systemPoint(body.position) - point).length < 1e-5
        else { return false }
      }
      let fresh = current.inertia(for: member.station)
      if fresh != member.prior {
        guard let fresh, let prior = member.prior,
          fresh.isCapturedCoastSuccessor(of: prior, through: end)
        else { return false }
      }
    }
    return true
  }

  private static func hasNoWorldClaims(_ game: borrowing Game) -> Bool {
    game.storedNativeStationResourcesAreEmpty()
      && game.commander.contracts.boards.values.allSatisfy {
        $0.station.stationClass == "main-orbital"
      }
      && game.commander.scriptState.instances.values.allSatisfy {
        $0.contract == nil || $0.contract?.station.stationClass == "main-orbital"
      }
  }
}

private enum NativeStationRefusalCapture {
  case unavailable
  case authenticated(NativeStationRefusalCohort)
}

/// Synchronous, acyclic, non-Sendable ownership of actual pre-movement facts.
final class AsteroidContactFrame {
  fileprivate let system: SystemIdentity
  fileprivate let visit: UInt64
  fileprivate let time: Double
  fileprivate let playerPose: ShipPose
  fileprivate let playerVelocity: Vector3
  fileprivate let actors: [DebrisActorFrame]
  fileprivate let celestials: [CelestialBody]
  fileprivate let bodyMotion: [DebrisBodyMotion]
  fileprivate let pilot: AutoTargetControl
  fileprivate let guidance: FlightWorkGuidance?
  fileprivate let braking: FlightWorkBraking?
  fileprivate let approved: HullSceneMotion?
  fileprivate let lastApplied: HullSceneMotion?
  fileprivate let residual: Bool
  fileprivate let recovery: RockIdentity?
  fileprivate let speed: Double
  fileprivate let startTime: Double
  fileprivate let stepDuration: Double
  fileprivate let stationReady: Bool
  private let stationRefusalCapture: NativeStationRefusalCapture
  private var consumed = false
  func identifiedSalvageSnapshot(_ actor: ActorIdentity)
    -> (mesh: Mesh, massKg: Double, debris: Bool, asteroid: Bool)?
  {
    guard let frame = actors.first(where: { $0.identity == actor }) else { return nil }
    return (frame.mesh, frame.mass, frame.debris, frame.asteroid)
  }
  fileprivate func capturedStationRefusalCohortAfterTake() -> NativeStationRefusalCohort? {
    guard consumed, case .authenticated(let value) = stationRefusalCapture else { return nil }
    return value
  }
  fileprivate var stationCaptureIsAuthenticated: Bool {
    if case .authenticated = stationRefusalCapture { return true }
    return false
  }
  fileprivate func take() -> Bool {
    guard !consumed else { return false }
    consumed = true
    return true
  }
  @inline(never)
  fileprivate init(
    game: borrowing Game, startTime: Double, stepDuration: Double, stationReady: Bool,
    excluding actorsBornAtEnd: Set<ActorIdentity> = []
  ) {
    self.startTime = startTime
    self.stepDuration = stepDuration
    self.stationReady = stationReady
    system = game.systemIdentity
    visit = game.storedFlightSimulation().visit
    time = game.storedFlightSimulation().physicalTime
    playerPose = game.storedFlightSimulation().pose
    playerVelocity = game.flightWorldVelocity
    celestials = game.celestials
    pilot = game.autoPilot
    guidance = game.workGuidance
    braking = game.workBraking
    approved = game.approvedWorkMotion
    lastApplied = game.lastAppliedWorkMotion
    residual = game.manualResidualFlight
    recovery = game.workRecoveryRock
    speed = game.speed
    bodyMotion = game.bodies.map {
      .init(
        id: $0.id, identity: $0.physical?.identity, position: $0.position,
        orientation: $0.orientation, rotation: $0.rotation, velocity: $0.physical?.velocity,
        npcViewVelocity: $0.scriptNPC?.velocity, shotViewVelocity: $0.scriptShot?.velocity)
    }
    var snapshots: [DebrisActorFrame] = []
    if let player = game.storedFlightSimulation().player {
      snapshots.append(
        .init(
          identity: player, bodyID: nil, pose: playerPose,
          velocity: playerVelocity, mesh: game.commander.playerMesh,
          mass: AsteroidImpactPolicy.massKg(hull: .cobra), debris: false, asteroid: false,
          station: nil, hull: .cobra,
          localOrientation: .init(), rotation: 0))
    }
    for body in game.bodies where body.energy > 0 {
      guard let physical = body.physical, physical.identity.system == system,
        physical.identity.visit == visit, physical.ordnance == nil, body.scriptShot == nil
      else { continue }
      if actorsBornAtEnd.contains(physical.identity) { continue }
      let mass = game.asteroidDebrisMassKg(body)
      let mesh: Mesh
      let collisionMass: Double
      let surveyor = game.c01SurveyorCollision(body) ?? game.c01TimingStandardCollision(body)
        ?? game.c01LaneRepairCollision(body) ?? game.c01ClinicCollision(body)
      if let surveyor {
        mesh = surveyor.mesh
        collisionMass = surveyor.mass
      } else if let recorder = game.recordRecoveryCollision(body) {
        mesh = recorder.mesh
        collisionMass = recorder.mass
      } else if let original = game.identifiedSalvageCollision(body) {
        mesh = original.mesh
        collisionMass = original.mass
      } else if let identity = body.nativeStationIdentity {
        guard let source = NativeStationSource.binding(for: identity),
          let world = game.storedNativeStationWorld(),
          let record = world.ledger.records.first(where: { $0.identity == identity }),
          NativeStationSource.authentic(record, owner: world.ledger.world)
        else {
          actors = []
          stationRefusalCapture = .unavailable
          return
        }
        mesh = source.geometry.mesh
        collisionMass = source.physical.dryMassKilograms
      } else {
        mesh = game.gameplayMesh(for: body)
        collisionMass = mass ?? AsteroidImpactPolicy.massKg(hull: body.hull)
      }
      let station = game.stationInertialIdentity(for: body, at: startTime)
      let movingStation: Bool
      if let station {
        movingStation = game.storedNativeStationWorld()?.inertia(for: station) != nil
      } else {
        movingStation = false
      }
      snapshots.append(
        .init(
          identity: physical.identity, bodyID: body.id,
          pose: game.modelPose(of: body), velocity: physical.velocity,
          mesh: mesh,
          mass: collisionMass,
          debris: mass != nil || movingStation || surveyor != nil, asteroid: mass != nil,
          station: station,
          hull: body.hull, localOrientation: body.orientation,
          rotation: body.rotation))
    }
    actors = snapshots
    if let cohort = NativeStationRefusalCohort(capturing: game, start: startTime, end: time,
      usedDuration: stepDuration, stationReady: stationReady),
      Set(snapshots.compactMap(\.station)) == Set(cohort.members.map(\.station)).union(
        snapshots.compactMap { actor -> StationInertialIdentity? in
          guard let station = actor.station, case .main = station,
            !cohort.members.contains(where: { $0.station == station }) else { return nil }
          return station
        }),
      cohort.members.allSatisfy({ member in snapshots.filter {
        $0.station == member.station && $0.identity == member.actor && $0.bodyID == member.bodyID
      }.count == 1 })
    {
      stationRefusalCapture = .authenticated(cohort)
    } else {
      stationRefusalCapture = .unavailable
    }
  }
}

#if DEBUG
  private func debrisRefusalVector(_ value: Vector3) -> String {
    String(format: "%.17g,%.17g,%.17g", value.x, value.y, value.z)
  }

  private func debrisRefusalPose(_ value: ShipPose) -> String {
    "p=" + debrisRefusalVector(value.position)
      + ";x=" + debrisRefusalVector(value.orientation.x)
      + ";y=" + debrisRefusalVector(value.orientation.y)
      + ";z=" + debrisRefusalVector(value.orientation.z)
  }

  private func debrisRefusalMotion(_ value: HullSceneMotion) -> String {
    "start=[" + debrisRefusalPose(value.start) + "];end=[" + debrisRefusalPose(value.end)
      + "];v=" + debrisRefusalVector(value.initialVelocity)
      + ";a=" + debrisRefusalVector(value.acceleration)
      + ";omega=" + debrisRefusalVector(value.worldAngularVelocity)
      + ";duration=" + String(value.duration) + ";radius=" + String(value.playerRadius)
  }
#endif

private struct DebrisTrajectory {
  let frame: DebrisActorFrame
  let hull: PreparedHull
  var motion: HullSceneMotion
  let endVelocity: Vector3
}

private struct DebrisPlannedImpact {
  let contact: NativeHullContact
  let impulse: AsteroidImpulse
  let offset: Double
  let player: ShipPose
  let source: ShipPose
  let target: ShipPose
}

extension Game {
  @inline(never)
  mutating func beginAsteroidContactStep(
    delta: Double = 0, excluding actorsBornAtEnd: Set<ActorIdentity> = []
  ) -> AsteroidContactFrame? {
    guard !docked else { return nil }
    let start = max(0, storedFlightSimulation().physicalTime - delta)
    let ready = synchronizeNativeStationInertia(at: start)
    let moving = bodies.contains {
      guard let id = stationInertialIdentity(for: $0, at: start) else { return false }
      return storedNativeStationWorld()?.inertia(for: id) != nil
    }
    var requiresFrame = moving || !ready
    if !requiresFrame {
      requiresFrame = bodies.contains(where: { asteroidDebrisMassKg($0) != nil })
    }
    if !requiresFrame, commander.scriptState.savedRecordRecoverySource != nil {
      requiresFrame = bodies.contains(where: { recordRecoveryAlias($0) != nil })
    }
    if !requiresFrame, commander.scriptState.savedIdentifiedSalvageSource != nil {
      requiresFrame = bodies.contains(where: { identifiedSalvageAlias($0) != nil })
    }
    if !requiresFrame, glassMeridianMission?.savedGlassMeridian?.surveyor != nil {
      requiresFrame = bodies.contains(where: { c01SurveyorCollision($0) != nil })
    }
    if !requiresFrame, glassMeridianMission?.savedGlassMeridian?.timingStandard != nil {
      requiresFrame = bodies.contains(where: { c01TimingStandardCollision($0) != nil })
    }
    if !requiresFrame, glassMeridianMission?.savedGlassMeridian?.laneRepair != nil {
      requiresFrame = bodies.contains(where: {
        c01LaneRepairCollision($0) != nil || c01ClinicCollision($0) != nil
      })
    }
    guard requiresFrame else { return nil }
    return AsteroidContactFrame(
      game: self, startTime: start, stepDuration: delta, stationReady: ready,
      excluding: actorsBornAtEnd)
  }

  /// Planning is pure with respect to resources and motion. Unsupported or unproven
  /// contacts retain the complete captured movement; no receipt or damage is invented.
  @inline(never)
  mutating func completeAsteroidContactStep(
    _ frame: AsteroidContactFrame?, delta: Double
  ) -> AsteroidContactStepResult {
    guard let frame else {
      return synchronizeNativeStationInertia(at: storedFlightSimulation().physicalTime)
        ? .advanced(nil) : .refused("STATION COAST UNPROVEN")
    }
    return completeCapturedAsteroidContactStep(frame, delta: delta)
  }

  @inline(never)
  private mutating func completeCapturedAsteroidContactStep(
    _ frame: AsteroidContactFrame, delta: Double
  ) -> AsteroidContactStepResult {
    guard frame.system == systemIdentity, frame.visit == storedFlightSimulation().visit,
      frame.time == storedFlightSimulation().physicalTime, frame.take()
    else { return .refused("STALE STEP") }
    guard delta.isFinite, delta > 0, delta <= 0.1, frame.time >= delta,
      frame.actors.count <= 129
    else { return refuseDebrisStep(frame, reason: "INVALID STEP") }
    guard frame.stationReady, frame.stationCaptureIsAuthenticated,
      synchronizeNativeStationInertia(
        at: storedFlightSimulation().physicalTime,
        advancingFrom: frame.startTime)
    else { return refuseDebrisStep(frame, reason: "STATION COAST UNPROVEN") }
    var trajectories: [DebrisTrajectory] = []
    for actor in frame.actors {
      let end: ShipPose
      let velocity: Vector3
      if let id = actor.bodyID {
        guard
          let body = bodies.first(where: { $0.id == id && $0.physical?.identity == actor.identity }
          ),
          body.energy > 0
        else { return refuseDebrisStep(frame, reason: "ACTOR CHANGED") }
        let currentMesh: Mesh
        if let surveyor = c01SurveyorCollision(body) ?? c01TimingStandardCollision(body)
          ?? c01LaneRepairCollision(body) ?? c01ClinicCollision(body)
        {
          currentMesh = surveyor.mesh
        } else if let recorder = recordRecoveryCollision(body) {
          currentMesh = recorder.mesh
        } else if let original = identifiedSalvageCollision(body) {
          currentMesh = original.mesh
        } else {
          currentMesh = gameplayMesh(for: body)
        }
        guard actor.mesh.vertices == currentMesh.vertices,
          actor.mesh.faces == currentMesh.faces
        else { return refuseDebrisStep(frame, reason: "ACTOR CHANGED") }
        end = modelPose(of: body)
        velocity = body.physical?.velocity ?? .init(0, 0, 0)
      } else {
        end = storedFlightSimulation().pose
        velocity = flightWorldVelocity
      }
      guard let hull = preparedWorkHull(mesh: actor.mesh, key: "debris:\(actor.identity.entity)"),
        let motion = debrisRigidMotion(
          from: actor.pose, to: end, duration: delta, radius: hull.radius)
      else { return refuseDebrisStep(frame, reason: "INVALID MOTION") }
      let actual: HullSceneMotion
      if actor.bodyID == nil, let approved = lastAppliedWorkMotion,
        approved.start == actor.pose, approved.end == end, approved.duration == delta
      {
        actual = .init(
          start: approved.start, end: approved.end,
          initialVelocity: approved.initialVelocity, acceleration: approved.acceleration,
          worldAngularVelocity: approved.worldAngularVelocity, duration: delta,
          playerRadius: hull.radius)
      } else {
        actual = motion
      }
      trajectories.append(.init(frame: actor, hull: hull, motion: actual, endVelocity: velocity))
    }
    var selected: (Int, Int, NativeHullContact)?
    var pairs = 0
    for source in trajectories.indices where trajectories[source].frame.debris {
      for target in trajectories.indices where target != source {
        if trajectories[source].frame.station != nil && trajectories[target].frame.asteroid {
          continue
        }
        if trajectories[target].frame.debris && target < source
          && !(trajectories[source].frame.asteroid && trajectories[target].frame.station != nil)
        {
          continue
        }
        guard debrisMayIntersect(trajectories[source], trajectories[target]) else { continue }
        pairs += 1
        guard pairs <= AsteroidImpactPolicy.maximumCandidatePairs else {
          return refuseDebrisStep(frame, reason: "CONTACT CAPACITY")
        }
        let result = HullSweepSafety.firstNativeContact(
          source: trajectories[source].motion, hull: trajectories[source].hull,
          target: trajectories[target].motion, targetHull: trajectories[target].hull)
        switch result {
        case .clear: continue
        case .refused(let failure):
          return refuseDebrisStep(frame, reason: "SWEEP UNPROVEN: " + failure.message)
        case .contact(let contact):
          if selected == nil || contact.lowerTime < selected!.2.lowerTime {
            selected = (source, target, contact)
          }
        }
      }
    }
    guard let (source, target, contact) = selected else { return .advanced(nil) }
    if let id = trajectories[target].frame.bodyID,
      let body = bodies.first(where: { $0.id == id }), body.scriptNPC != nil,
      c01SurveyorCollision(body) == nil, c01TimingStandardCollision(body) == nil,
      c01LaneRepairCollision(body) == nil, c01ClinicCollision(body) == nil
    {
      return refuseDebrisStep(frame, reason: "MISSION INERTIA AUTHORITY UNAVAILABLE")
    }
    for index in [source, target] {
      let trajectory = trajectories[index]
      let expected = trajectory.motion.initialVelocity + trajectory.motion.acceleration * delta
      guard (expected - trajectory.endVelocity).length < 1e-5 else {
        return refuseDebrisStep(frame, reason: "NATIVE VELOCITY UNPROVEN")
      }
    }
    if trajectories[source].frame.station == nil && trajectories[target].frame.station == nil {
      return stageContinuingDebrisContacts(
        frame, trajectories: trajectories,
        source: source, target: target, contact: contact, pairs: pairs, delta: delta)
    }
    guard
      let impulse = AsteroidImpactPolicy.impulse(
        sourceMass: trajectories[source].frame.mass, targetMass: trajectories[target].frame.mass,
        sourceVelocity: trajectories[source].motion.initialVelocity
          + trajectories[source].motion.acceleration * contact.lowerTime,
        targetVelocity: trajectories[target].motion.initialVelocity
          + trajectories[target].motion.acceleration * contact.lowerTime,
        normal: contact.normal)
    else { return refuseDebrisStep(frame, reason: "IMPULSE UNPROVEN") }
    // Do not advance a new post-impact path without proving its entire remaining interval.
    let contactPlayerPose =
      trajectories.first { $0.frame.bodyID == nil }
      .map { debrisPose($0.motion, at: contact.upperTime) } ?? storedFlightSimulation().pose
    let contactSourcePose = debrisPose(trajectories[source].motion, at: contact.upperTime)
    let contactTargetPose = debrisPose(trajectories[target].motion, at: contact.upperTime)
    let remainder = delta - contact.lowerTime
    for index in [source, target] {
      let original = trajectories[index].motion
      let pose = debrisPose(original, at: contact.lowerTime)
      let velocity = index == source ? impulse.source : impulse.target
      let end = debrisAdvancedPose(
        pose, velocity: velocity,
        omega: original.worldAngularVelocity, time: remainder)
      trajectories[index].motion = .init(
        start: pose, end: end, initialVelocity: velocity,
        acceleration: .init(0, 0, 0), worldAngularVelocity: original.worldAngularVelocity,
        duration: remainder, playerRadius: trajectories[index].hull.radius)
    }
    for index in trajectories.indices where index != source && index != target {
      let original = trajectories[index].motion
      let start = debrisPose(original, at: contact.lowerTime)
      trajectories[index].motion = .init(
        start: start, end: original.end,
        initialVelocity: original.initialVelocity + original.acceleration * contact.lowerTime,
        acceleration: original.acceleration,
        worldAngularVelocity: original.worldAngularVelocity, duration: remainder,
        playerRadius: trajectories[index].hull.radius)
    }
    for a in trajectories.indices where trajectories[a].frame.debris {
      for b in trajectories.indices where b != a {
        if trajectories[a].frame.station != nil && trajectories[b].frame.asteroid { continue }
        if trajectories[b].frame.debris && b < a
          && !(trajectories[a].frame.asteroid && trajectories[b].frame.station != nil)
        {
          continue
        }
        guard debrisMayIntersect(trajectories[a], trajectories[b]) else { continue }
        pairs += 1
        guard pairs <= AsteroidImpactPolicy.maximumCandidatePairs else {
          return refuseDebrisStep(frame, reason: "CONTACT CAPACITY")
        }
        let result = HullSweepSafety.firstNativeContact(
          source: trajectories[a].motion,
          hull: trajectories[a].hull, target: trajectories[b].motion,
          targetHull: trajectories[b].hull)
        switch result {
        case .clear: break
        case .contact:
          return refuseDebrisStep(frame, reason: "REMAINING CONTACT")
        case .refused(let failure):
          return refuseDebrisStep(frame, reason: "REMAINING SWEEP UNPROVEN: " + failure.message)
        }
      }
    }
    var stationTransfers: [StationContactTransfer] = []
    for index in [source, target] where trajectories[index].frame.hull == .station {
      let actor = trajectories[index].frame
      guard let station = actor.station, let id = actor.bodyID else {
        return refuseDebrisStep(frame, reason: "STATION IDENTITY UNAVAILABLE")
      }
      stationTransfers.append(
        .init(
          station: station, actor: actor.identity, bodyID: id,
          system: systemIdentity, visit: storedFlightSimulation().visit,
          physicalTime: storedFlightSimulation().physicalTime,
          impactTime: frame.time - delta + contact.lowerTime, previousVelocity: actor.velocity,
          finalPosition: trajectories[index].motion.end.position,
          finalVelocity: index == source ? impulse.source : impulse.target,
          impulse: index == source ? impulse.transferred * -1 : impulse.transferred,
          damage: index == target ? impulse.damage : 0))
    }
    let stationPlan: PreparedStationTransfers?
    if stationTransfers.isEmpty {
      stationPlan = nil
    } else {
      guard let prepared = prepareStationTransfers(stationTransfers) else {
        return refuseDebrisStep(frame, reason: "STATION EFFECT REFUSED")
      }
      stationPlan = prepared
    }
    let simulation = storedFlightSimulation()
    guard simulation.nextEmission < UInt64.max - 1, simulation.nextIncident < UInt64.max - 3 else {
      return refuseDebrisStep(frame, reason: "INCIDENT CAPACITY")
    }
    // The synchronous current actor join is checked again immediately before mutation.
    guard let sourceID = trajectories[source].frame.bodyID,
      let sourceBody = bodies.first(where: { $0.id == sourceID }),
      sourceBody.physical?.identity == trajectories[source].frame.identity,
      sourceBody.energy > 0
    else { return refuseDebrisStep(frame, reason: "STALE CONTACT") }
    guard let context = gameplayContext() else {
      return refuseDebrisStep(frame, reason: "CONTEXT UNAVAILABLE")
    }
    let targetIdentity = trajectories[target].frame.identity
    let trialOrigin = AttackOrigin(
      emissionID: simulation.nextEmission,
      owner: trajectories[source].frame.identity, emittedAt: context.physicalTime,
      ownerLegalAtEmission: .init())
    let trial = CombatIncident(
      id: simulation.nextIncident, physicalTime: context.physicalTime,
      origin: trialOrigin, victim: targetIdentity, kind: .collision, outcome: .hit,
      position: contact.point, victimLegalBeforeAttack: nil, firstAggressor: nil,
      victimRole: nil, victimIsStation: false)
    var law = commander.crimeLedger
    guard law.record(trial, context: context).accepted else {
      return refuseDebrisStep(frame, reason: "INCIDENT REFUSED")
    }
    mapDebrisEffectToContact(
      player: contactPlayerPose,
      sourceID: sourceID, source: contactSourcePose,
      targetID: trajectories[target].frame.bodyID, target: contactTargetPose)
    let allocated = makeAttackOrigin(owner: trajectories[source].frame.identity)
    guard let origin = allocated else { return refuseDebrisStep(frame, reason: "INCIDENT REFUSED") }
    let targetActor = trajectories[target].frame
    let targetHit: GameplayHitTarget = targetActor.bodyID.map { .body($0) } ?? .player
    let hit = GameplayHit(
      target: targetHit, distance: 0,
      point: storedFlightSimulation().pose.shipPoint(contact.point))
    // Native collision incidents bypass attack/bounty law but use the ordinary real damage
    // and destruction authorities. No weapon discharge or mission success is synthesized.
    let incident: CombatIncident?
    if trajectories[target].frame.station != nil {
      incident = recordCombat(
        origin: origin, kind: .collision, outcome: .hit,
        target: targetHit, worldPosition: contact.point)
    } else {
      incident = applyCombatHit(hit, origin: origin, kind: .collision, damage: impulse.damage)
    }
    guard let incident else {
      let effectPose = storedFlightSimulation().pose
      commander.flightSimulation = simulation
      commander.flightSimulation.pose = effectPose
      return refuseDebrisStep(frame, reason: "DAMAGE REFUSED")
    }
    stationPlan?.commit(to: &self)
    if trajectories[target].frame.station != nil, let id = targetActor.bodyID,
      let index = bodies.firstIndex(where: { $0.id == id }), bodies[index].energy <= 0
    {
      let death = recordCombat(
        origin: origin, kind: .collision, outcome: .destruction,
        target: targetHit, worldPosition: contact.point)
      bodies[index].physical?.deathOrigin = origin
      bodies[index].physical?.deathIncidentID = death?.id
      bodies[index].destroyedByPlayer = false
    }
    commander.crimeLedger.finishEmission(origin.emissionID)
    commitDebrisMotion(trajectories, source: source, target: target, impulse: impulse)
    persistAsteroidBreakupMotion()
    persistOrePoses()
    return .advanced(
      .init(
        source: trajectories[source].frame.identity, target: targetActor.identity,
        point: contact.point, transferredMomentum: impulse.transferred,
        damage: impulse.damage, incident: incident.id,
        contactPhysicalTime: frame.time - delta + contact.upperTime))
  }

  /// Keep health, law, pose and resource changes in a value candidate until the
  /// entire chronological response and every actual effect have been accepted.
  @inline(never)
  private mutating func stageContinuingDebrisContacts(
    _ frame: AsteroidContactFrame, trajectories: [DebrisTrajectory],
    source: Int, target: Int, contact: NativeHullContact, pairs: Int, delta: Double
  ) -> AsteroidContactStepResult {
    var candidate = self
    let result = candidate.applyContinuingDebrisContacts(
      frame, trajectories: trajectories,
      source: source, target: target, contact: contact, pairs: pairs, delta: delta)
    switch result {
    case .advanced:
      self = candidate
      return result
    case .refused(let reason):
      return refuseDebrisStep(frame, reason: reason)
    }
  }

  @inline(never)
  private mutating func applyContinuingDebrisContacts(
    _ frame: AsteroidContactFrame, trajectories original: [DebrisTrajectory],
    source: Int, target: Int, contact first: NativeHullContact, pairs initialPairs: Int,
    delta: Double
  ) -> AsteroidContactStepResult {
    var trajectories = original
    var pairs = initialPairs
    var contact = first
    var offset = 0.0
    var impacts: [DebrisPlannedImpact] = []
    var normals: [Vector3] = []
    while true {
      let absoluteLower = offset + contact.lowerTime
      guard impacts.isEmpty || (contact.lowerTime > 0 && absoluteLower > offset),
        let frontier = HullSweepSafety.nativeFrontierPoses(
          contact,
          sourceHull: trajectories[source].hull, targetHull: trajectories[target].hull)
      else { return .refused("CONTINUATION UNPROVEN") }
      if !normals.contains(contact.normal) { normals.append(contact.normal) }
      guard
        let impulse = AsteroidImpactPolicy.impulse(
          sourceMass: trajectories[source].frame.mass, targetMass: trajectories[target].frame.mass,
          sourceVelocity: trajectories[source].motion.initialVelocity
            + trajectories[source].motion.acceleration * contact.lowerTime,
          targetVelocity: trajectories[target].motion.initialVelocity
            + trajectories[target].motion.acceleration * contact.lowerTime,
          normals: normals)
      else { return .refused("CONTINUATION UNPROVEN") }
      let playerPose =
        trajectories.first { $0.frame.bodyID == nil }
        .map { debrisPose($0.motion, at: contact.upperTime) } ?? storedFlightSimulation().pose
      impacts.append(
        .init(
          contact: contact, impulse: impulse, offset: offset,
          player: playerPose,
          source: debrisPose(trajectories[source].motion, at: contact.upperTime),
          target: debrisPose(trajectories[target].motion, at: contact.upperTime)))
      let advance = contact.lowerTime
      offset = absoluteLower
      let remainder = delta - offset
      guard remainder > 0 else { return .refused("CONTINUATION UNPROVEN") }
      for index in trajectories.indices {
        let old = trajectories[index].motion
        let start: ShipPose
        let velocity: Vector3
        let acceleration: Vector3
        let end: ShipPose
        if index == source || index == target {
          start = index == source ? frontier.source : frontier.target
          velocity = index == source ? impulse.source : impulse.target
          acceleration = .init(0, 0, 0)
          end = debrisAdvancedPose(
            start, velocity: velocity,
            omega: old.worldAngularVelocity, time: remainder)
        } else {
          start = debrisPose(old, at: advance)
          velocity = old.initialVelocity + old.acceleration * advance
          acceleration = old.acceleration
          end = old.end
        }
        trajectories[index].motion = .init(
          start: start, end: end,
          initialVelocity: velocity, acceleration: acceleration,
          worldAngularVelocity: old.worldAngularVelocity, duration: remainder,
          playerRadius: trajectories[index].hull.radius)
      }
      var next: NativeHullContact?
      for a in trajectories.indices where trajectories[a].frame.debris {
        for b in trajectories.indices where b != a {
          if trajectories[a].frame.station != nil && trajectories[b].frame.asteroid { continue }
          if trajectories[b].frame.debris && b < a
            && !(trajectories[a].frame.asteroid && trajectories[b].frame.station != nil)
          {
            continue
          }
          let samePair = a == source && b == target
          guard samePair || debrisMayIntersect(trajectories[a], trajectories[b]) else { continue }
          pairs += 1
          guard pairs <= AsteroidImpactPolicy.maximumCandidatePairs else {
            return .refused("CONTACT CAPACITY")
          }
          let result: NativeHullContactResult
          if samePair {
            result = HullSweepSafety.continueNativeContact(
              contact,
              source: trajectories[a].motion, hull: trajectories[a].hull,
              target: trajectories[b].motion, targetHull: trajectories[b].hull)
          } else {
            result = HullSweepSafety.firstNativeContact(
              source: trajectories[a].motion,
              hull: trajectories[a].hull, target: trajectories[b].motion,
              targetHull: trajectories[b].hull)
          }
          switch result {
          case .clear: break
          case .contact(let found):
            guard samePair else { return .refused("REMAINING CONTACT") }
            next = found
          case .refused(let failure):
            #if DEBUG
              // Retain the failed geometric query in ordinary debug/test logs. The candidate
              // is discarded below; no contact or player-facing diagnostic detail is invented.
              let sourceID = trajectories[a].frame.bodyID.map(String.init) ?? "player"
              let targetID = trajectories[b].frame.bodyID.map(String.init) ?? "player"
              let facts =
                "source=" + sourceID + " target=" + targetID
                + " samePair=" + String(samePair)
                + " lower=" + String(contact.lowerTime) + " upper=" + String(contact.upperTime)
                + " offset=" + String(offset) + " remainder=" + String(remainder)
                + " sourceMotion=" + debrisRefusalMotion(trajectories[a].motion)
                + " targetMotion=" + debrisRefusalMotion(trajectories[b].motion)
              NSLog("DEBRIS_REMAINING_SWEEP_REFUSAL %@ %@", failure.message, facts)
            #endif
            return .refused("REMAINING SWEEP UNPROVEN: " + failure.message)
          }
        }
      }
      guard let next else { break }
      contact = next
    }
    let simulation = storedFlightSimulation()
    let reserved = UInt64(impacts.count)
    guard simulation.nextEmission < UInt64.max - reserved,
      simulation.nextIncident < UInt64.max - reserved * 3,
      let sourceID = trajectories[source].frame.bodyID,
      let sourceBody = bodies.first(where: { $0.id == sourceID }),
      sourceBody.physical?.identity == trajectories[source].frame.identity, sourceBody.energy > 0
    else { return .refused("INCIDENT CAPACITY") }
    let targetActor = trajectories[target].frame
    var receipt: AsteroidImpactReceipt?
    for impact in impacts {
      // A later mechanical response still conserves momentum after destruction,
      // but cannot settle health, death or rewards for the same victim twice.
      let alive: Bool
      if let id = targetActor.bodyID {
        guard let body = bodies.first(where: { $0.id == id }),
          body.physical?.identity == targetActor.identity
        else { return .refused("STALE CONTACT") }
        alive = body.energy > 0
      } else {
        alive = energy > 0
      }
      guard alive else { continue }
      guard
        let effect = applyNativeDebrisContactEffect(
          contact: impact.contact, impulse: impact.impulse,
          sourceID: sourceID, sourceActor: trajectories[source].frame.identity,
          targetID: targetActor.bodyID, targetActor: targetActor.identity,
          playerPose: impact.player, sourcePose: impact.source, targetPose: impact.target,
          contactPhysicalTime: frame.time - delta + impact.offset + impact.contact.upperTime)
      else { return .refused("DAMAGE REFUSED") }
      if receipt == nil { receipt = effect }
    }
    guard let receipt, let last = impacts.last else { return .refused("DAMAGE REFUSED") }
    commitDebrisMotion(trajectories, source: source, target: target, impulse: last.impulse)
    persistAsteroidBreakupMotion()
    persistOrePoses()
    return .advanced(receipt)
  }

  /// Shared native consequence kernel. The curved contact owner first invokes
  /// this on its inert prepared candidate, then once on actual retention. It
  /// must retain the selected endpoints after this impact-frame health pass.
  /// NativeHullContact has no caller or save constructor.
  mutating func applyNativeDebrisContactEffect(
    contact: NativeHullContact, impulse: AsteroidImpulse,
    sourceID: Int, sourceActor: ActorIdentity,
    targetID: Int?, targetActor: ActorIdentity,
    playerPose: ShipPose, sourcePose: ShipPose, targetPose: ShipPose,
    contactPhysicalTime: Double, captureClockEffect: Bool = false
  ) -> AsteroidImpactReceipt? {
    guard contactPhysicalTime.isFinite, contactPhysicalTime >= 0,
      contactPhysicalTime <= commander.flightSimulation.physicalTime + 1e-9,
      let source = bodies.first(where: { $0.id == sourceID }),
      source.physical?.identity == sourceActor, source.energy > 0,
      impulse.damage.isFinite, impulse.damage >= 0, impulse.transferred.finite
    else { return nil }
    if let targetID {
      guard let target = bodies.first(where: { $0.id == targetID }),
        target.physical?.identity == targetActor, target.energy > 0
      else { return nil }
    } else {
      guard commander.flightSimulation.player == targetActor, energy > 0 else { return nil }
    }
    let opening = commander.flightSimulation
    mapDebrisEffectToContact(
      player: playerPose, sourceID: sourceID, source: sourcePose,
      targetID: targetID, target: targetPose)
    guard let origin = makeAttackOrigin(owner: sourceActor) else { return nil }
    let hit = GameplayHit(
      target: targetID.map { .body($0) } ?? .player,
      distance: 0, point: storedFlightSimulation().pose.shipPoint(contact.point))
    let incident: CombatIncident
    let clockEffect: NativeDebrisImpactClockEffect?
    if captureClockEffect {
      guard let effect = applyNativeCollisionHit(hit, origin: origin, damage: impulse.damage)
      else { return nil }
      let proof = NativeDebrisImpactClockEffect(
        opening: opening, playerPose: playerPose, hit: effect)
      guard proof.applying(to: opening) == commander.flightSimulation else { return nil }
      incident = effect.incident
      clockEffect = proof
    } else {
      guard
        let accepted = applyCombatHit(
          hit, origin: origin, kind: .collision,
          damage: impulse.damage)
      else { return nil }
      incident = accepted
      clockEffect = nil
    }
    commander.crimeLedger.finishEmission(origin.emissionID)
    return .init(
      source: sourceActor, target: targetActor, point: contact.point,
      transferredMomentum: impulse.transferred, damage: impulse.damage, incident: incident.id,
      contactPhysicalTime: contactPhysicalTime, clockEffect: clockEffect)
  }

  private mutating func refuseDebrisStep(_ frame: AsteroidContactFrame, reason: String)
    -> AsteroidContactStepResult
  {
    let previous = storedFlightSimulation().pose
    rotateScriptNPCVelocities(from: previous, to: frame.playerPose)
    commander.flightSimulation.pose = frame.playerPose
    for index in bodies.indices {
      let body = bodies[index]
      if let captured = frame.bodyMotion.first(where: {
        $0.id == body.id && $0.identity == body.physical?.identity
      }) {
        bodies[index].position = captured.position
        bodies[index].orientation = captured.orientation
        bodies[index].rotation = captured.rotation
        if let velocity = captured.velocity { bodies[index].physical?.velocity = velocity }
        if let velocity = captured.npcViewVelocity { bodies[index].scriptNPC?.velocity = velocity }
        if let velocity = captured.shotViewVelocity {
          bodies[index].scriptShot?.velocity = velocity
        }
      } else {
        bodies[index].position = frame.playerPose.shipPoint(previous.systemPoint(body.position))
        let world = body.orientation.transformed(by: previous.orientation)
        bodies[index].orientation = world.relative(to: frame.playerPose.orientation)
      }
    }
    autoPilot = frame.pilot
    workGuidance = frame.guidance
    workBraking = frame.braking
    approvedWorkMotion = frame.approved
    lastAppliedWorkMotion = frame.lastApplied
    manualResidualFlight = frame.residual
    workRecoveryRock = frame.recovery
    speed = frame.speed
    celestials = frame.celestials
    let retained: Bool
    if let cohort = frame.capturedStationRefusalCohortAfterTake() {
      let stationRefusals = cohort.members.map { member in
        StationMotionRefusal(station: member.station, actor: member.actor, bodyID: member.bodyID,
          system: cohort.system, visit: cohort.visit, fromTime: cohort.start, toTime: cohort.end,
          duration: cohort.usedDuration, position: member.pose.position, velocity: member.velocity)
      }
      retained = retainNativeStationRefusal(stationRefusals, captured: cohort)
    } else {
      retained = false
    }
    paused = true
    notify(
      "DEBRIS CONTACT DEFERRED: " + reason
        + (retained ? "" : " / STATION ROLLBACK UNPROVEN"), voiced: false)
    return .refused(reason)
  }

  /// The normal native damage kernel sees the actually proved impact-time bank/axes.
  /// End-of-step positions must not choose the opposite shield after a fast crossing.
  private mutating func mapDebrisEffectToContact(
    player: ShipPose, sourceID: Int, source: ShipPose, targetID: Int?, target: ShipPose
  ) {
    let previous = storedFlightSimulation().pose
    rotateScriptNPCVelocities(from: previous, to: player)
    for index in bodies.indices {
      let body = bodies[index]
      let pose =
        body.id == sourceID
        ? source
        : body.id == targetID ? target : modelPose(of: body)
      setDebrisBodyPose(at: index, pose: pose, player: player)
    }
    for index in celestials.indices {
      celestials[index].position = player.shipPoint(
        previous.systemPoint(celestials[index].position))
    }
    commander.flightSimulation.pose = player
  }

  private mutating func setDebrisBodyPose(at index: Int, pose: ShipPose, player: ShipPose) {
    bodies[index].position = player.shipPoint(pose.position)
    let relative = pose.orientation.relative(to: player.orientation)
    let rotation = bodies[index].rotation
    var spin = Basis3()
    spin.rotate(pitch: bodies[index].hull == .station ? 0 : rotation * 0.4, roll: rotation, yaw: 0)
    bodies[index].orientation.x = relative.apply(spin.inverse(.init(1, 0, 0)))
    bodies[index].orientation.y = relative.apply(spin.inverse(.init(0, 1, 0)))
    bodies[index].orientation.z = relative.apply(spin.inverse(.init(0, 0, 1)))
  }

  private mutating func commitDebrisMotion(
    _ trajectories: [DebrisTrajectory], source: Int,
    target: Int, impulse: AsteroidImpulse
  ) {
    let previous = storedFlightSimulation().pose
    let player = trajectories.first { $0.frame.bodyID == nil }
    let end = player?.motion.end ?? previous
    rotateScriptNPCVelocities(from: previous, to: end)
    commander.flightSimulation.pose = end
    for index in bodies.indices {
      guard
        let trajectory = trajectories.first(where: {
          $0.frame.bodyID == bodies[index].id
            && $0.frame.identity == bodies[index].physical?.identity
        })
      else {
        bodies[index].position = end.shipPoint(previous.systemPoint(bodies[index].position))
        bodies[index].orientation = bodies[index].orientation.transformed(by: previous.orientation)
          .relative(to: end.orientation)
        continue
      }
      let pose = trajectory.motion.end
      bodies[index].position = end.shipPoint(pose.position)
      let relative = pose.orientation.relative(to: end.orientation)
      let rotation = bodies[index].rotation
      var spin = Basis3()
      spin.rotate(
        pitch: bodies[index].hull == .station ? 0 : rotation * 0.4, roll: rotation, yaw: 0)
      bodies[index].orientation.x = relative.apply(spin.inverse(.init(1, 0, 0)))
      bodies[index].orientation.y = relative.apply(spin.inverse(.init(0, 1, 0)))
      bodies[index].orientation.z = relative.apply(spin.inverse(.init(0, 0, 1)))
      if trajectory.frame.identity == trajectories[source].frame.identity {
        bodies[index].physical?.velocity = impulse.source
      } else if trajectory.frame.identity == trajectories[target].frame.identity {
        bodies[index].physical?.velocity = impulse.target
      }
    }
    for index in celestials.indices {
      celestials[index].position = end.shipPoint(previous.systemPoint(celestials[index].position))
    }
    if trajectories[target].frame.bodyID == nil {
      retainNativePlayerCollisionControls(outgoingVelocity: impulse.target, pose: end)
    }
  }

  mutating func retainNativePlayerCollisionControls(outgoingVelocity: Vector3, pose: ShipPose) {
    cancelAutoTarget()
    workGuidance = nil
    workBraking = nil
    approvedWorkMotion = nil
    speed = 0
    manualResidualFlight = true
    autoPilot.setApproachVelocity(pose.shipVector(outgoingVelocity))
  }
}

func debrisRigidMotion(
  from start: ShipPose, to end: ShipPose, duration: Double,
  radius: Double
) -> HullSceneMotion? {
  guard start.orientation.validRotation, end.orientation.validRotation,
    start.position.finite, end.position.finite, duration.isFinite, duration > 0
  else { return nil }
  let a = start.orientation
  let b = end.orientation
  var relative = Basis3()
  relative.x = b.apply(a.inverse(.init(1, 0, 0)))
  relative.y = b.apply(a.inverse(.init(0, 1, 0)))
  relative.z = b.apply(a.inverse(.init(0, 0, 1)))
  let angle = acos(max(-1, min(1, (relative.x.x + relative.y.y + relative.z.z - 1) * 0.5)))
  guard angle.isFinite, angle < 1 else { return nil }
  let skew = Vector3(
    relative.y.z - relative.z.y, relative.z.x - relative.x.z,
    relative.x.y - relative.y.x)
  let omega =
    angle < 1e-7
    ? skew * (0.5 / duration)
    : skew * (angle / (2 * sin(angle) * duration))
  return .init(
    start: start, end: end, initialVelocity: (end.position - start.position) * (1 / duration),
    acceleration: .init(0, 0, 0), worldAngularVelocity: omega, duration: duration,
    playerRadius: radius)
}

private func debrisPose(_ motion: HullSceneMotion, at time: Double) -> ShipPose {
  var pose = debrisAdvancedPose(
    motion.start, velocity: motion.initialVelocity,
    omega: motion.worldAngularVelocity, time: time)
  pose.position = pose.position + motion.acceleration * (0.5 * time * time)
  return pose
}

private func debrisAdvancedPose(
  _ start: ShipPose, velocity: Vector3, omega: Vector3,
  time: Double
) -> ShipPose {
  var pose = start
  pose.position = start.position + velocity * time
  if omega.length > 1e-12 {
    let axis = omega * (1 / omega.length)
    let angle = omega.length * time
    func rotated(_ value: Vector3) -> Vector3 {
      value * cos(angle) + axis.cross(value) * sin(angle)
        + axis * (axis.dot(value) * (1 - cos(angle)))
    }
    pose.orientation.x = rotated(start.orientation.x)
    pose.orientation.y = rotated(start.orientation.y)
    pose.orientation.z = rotated(start.orientation.z)
  }
  return pose
}

private func debrisMayIntersect(_ a: DebrisTrajectory, _ b: DebrisTrajectory) -> Bool {
  let start = a.motion.start.position - b.motion.start.position
  let end = a.motion.end.position - b.motion.end.position
  let travel = end - start
  let t = travel.dot(travel) > 0 ? max(0, min(1, -start.dot(travel) / travel.dot(travel))) : 0
  let gap = (start + travel * t).length
  let curve =
    (a.motion.acceleration - b.motion.acceleration).length
    * a.motion.duration * a.motion.duration / 8
  return !gap.isFinite || !curve.isFinite || gap <= a.hull.radius + b.hull.radius + curve + 1e-6
}
