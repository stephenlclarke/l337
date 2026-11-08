import Foundation

/// Untrusted projected facts, never proof of a retained mission or installed pack.
/// The Game resolver must obtain these from MC1's actual retained-record/pack/fit join.
struct MissionActorDescriptor: Equatable, Sendable {
  let instanceID: UUID
  let instanceRevision: UInt64
  let packDigest: String
  let encounterID: String
  let encounterAdmitted: Bool
  let system: SystemIdentity
  let alias: String
  let actorID: UUID
  /// Exact ScriptActorPresence.rawValue; a string alone grants no mission authority.
  let presence: String
  let missionActorID: UUID?
  let missionInstanceID: UUID?
  let body: SpaceBody
}

/// Authored values projected from an actual joined fit, not caller-selected damage authority.
struct MissionWeaponDescriptor: Equatable, Sendable {
  let id: String
  let kind: AttackKind
  let damage: Double
  let range: Double
  let projectileSpeed: Double?
  let lifetime: Double?
  let collisionRadius: Double?
  let collisionDelay: Double?
  /// Actual transformed muzzle and aim in the same frame used for collision queries.
  let muzzle: Vector3
  let direction: Vector3
}

/// Exact existing ScriptNPCShot fields. Archive and native judgement await their real provider.
struct MissionShotDescriptor: Equatable, Sendable {
  let identity: UUID
  let owner: UUID
  let instance: UUID
  let weapon: String
  let component: UUID?
  let velocity: Vector3
  let age: Double
  let lifetime: Double
  let damage: Double
  let radius: Double
  let collisionDelay: Double
}

enum MissionNativeBridgeError: Error, Equatable, Sendable {
  case invalidDescriptor, sourceMismatch, missingActor, invalidNativeBinding, staleBinding
  case unsupportedWeapon, invalidShot, invalidArchive, invalidGeometry
}

/// Seals only the checked native binding and projected facts, not the external durable join.
/// It is deliberately non-Codable: a load must resolve actual retained facts again.
struct MissionActorBinding: Equatable, Sendable {
  let instanceID: UUID
  let actorID: UUID
  let bodyID: Int
  let nativeActor: ActorIdentity
  fileprivate let descriptor: MissionActorDescriptor
  fileprivate let actorSnapshot: ActorSnapshot
  fileprivate let sceneRevision: UInt64

  fileprivate init(
    descriptor: MissionActorDescriptor, actorSnapshot: ActorSnapshot, sceneRevision: UInt64
  ) {
    instanceID = descriptor.instanceID
    actorID = descriptor.actorID
    bodyID = descriptor.body.id
    nativeActor = actorSnapshot.identity
    self.descriptor = descriptor
    self.actorSnapshot = actorSnapshot
    self.sceneRevision = sceneRevision
  }
}

/// Pure native checks only. G1's Game resolver must call the real MC1 descriptor factory
/// and revalidate that durable join before every use; no generic combat/admission bypass.
enum MissionNativeBridge {
  static func bindActor(
    descriptor: MissionActorDescriptor, body: SpaceBody, context: EncounterContext
  ) throws -> MissionActorBinding {
    let actor = try checkedActor(descriptor: descriptor, body: body, context: context)
    return .init(
      descriptor: descriptor, actorSnapshot: actor, sceneRevision: context.revision)
  }

  static func validateBinding(
    _ binding: MissionActorBinding, descriptor: MissionActorDescriptor,
    body: SpaceBody, context: EncounterContext
  ) throws {
    guard binding.descriptor == descriptor, descriptor.body == body,
      binding.sceneRevision == context.revision
    else { throw MissionNativeBridgeError.staleBinding }
    let actor = try checkedActor(descriptor: descriptor, body: body, context: context)
    guard actor == binding.actorSnapshot else { throw MissionNativeBridgeError.staleBinding }
  }

  private static func checkedActor(
    descriptor: MissionActorDescriptor, body: SpaceBody, context: EncounterContext
  ) throws -> ActorSnapshot {
    guard PackValidation.localID(descriptor.encounterID), PackValidation.localID(descriptor.alias),
      descriptor.packDigest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
      (0..<8).contains(descriptor.system.galaxy), (0...256).contains(descriptor.system.system),
      descriptor.encounterAdmitted, descriptor.presence == "present"
    else { throw MissionNativeBridgeError.invalidDescriptor }
    guard descriptor.missionActorID == descriptor.actorID,
      descriptor.missionInstanceID == descriptor.instanceID,
      body.missionActorID == descriptor.actorID, body.missionInstanceID == descriptor.instanceID,
      descriptor.body == body,
      descriptor.system == context.system
    else { throw MissionNativeBridgeError.sourceMismatch }
    guard body.id >= 0, body.energy.isFinite, body.energy > 0,
      body.position.finite, body.orientation.validRotation,
      body.rotation.isFinite, body.rotationRate.isFinite, let physical = body.physical,
      physical.velocity.finite, physical.angularVelocity.finite,
      context.visit > 0, context.visit < UInt64.max,
      context.physicalTime.isFinite, context.physicalTime >= 0,
      physical.identity.entity >= 2, physical.identity.entity < UInt64.max,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      physical.population == .mission, physical.npc?.role == .mission,
      context.protection.protectedActors.contains(physical.identity)
    else { throw MissionNativeBridgeError.invalidNativeBinding }
    let actors = context.actors.filter { $0.identity == physical.identity }
    guard actors.count == 1, let actor = actors.first else {
      throw MissionNativeBridgeError.missingActor
    }
    guard actor.hull == body.hull, actor.energy == body.energy,
      actor.position.finite, actor.orientation.validRotation,
      actor.velocity.finite, actor.angularVelocity.finite,
      actor.maximumEnergy.isFinite, actor.maximumEnergy >= 0,
      actor.maximumSpeedUnitsPerSecond.isFinite, actor.maximumSpeedUnitsPerSecond >= 0,
      actor.npc == physical.npc, actor.npc?.role == .mission
    else { throw MissionNativeBridgeError.invalidNativeBinding }
    return actor
  }

  /// Structural compatibility only; the Game resolver must prove this is the actual weapon.
  static func validateWeapon(_ weapon: MissionWeaponDescriptor) throws {
    guard PackValidation.localID(weapon.id), weapon.muzzle.finite, weapon.direction.finite,
      abs(weapon.direction.length - 1) < 1e-6,
      [weapon.damage, weapon.range].allSatisfy({
        $0.isFinite && (0.001...100_000).contains($0)
      })
    else { throw MissionNativeBridgeError.unsupportedWeapon }
    switch weapon.kind {
    case .laser:
      guard
        [weapon.projectileSpeed, weapon.lifetime, weapon.collisionRadius, weapon.collisionDelay]
          .allSatisfy({ $0 == nil })
      else { throw MissionNativeBridgeError.unsupportedWeapon }
    case .plasma:
      guard let speed = weapon.projectileSpeed, speed.isFinite, (1...100_000).contains(speed),
        let lifetime = weapon.lifetime, lifetime.isFinite, (0.01...60).contains(lifetime),
        let radius = weapon.collisionRadius, radius.isFinite, (0.01...100).contains(radius),
        let delay = weapon.collisionDelay, delay.isFinite, (0...10).contains(delay),
        delay < lifetime
      else { throw MissionNativeBridgeError.unsupportedWeapon }
    default:
      throw MissionNativeBridgeError.unsupportedWeapon
    }
  }

  /// Mirrors the existing shot bounds without allocating or deriving an attack owner.
  static func validateShot(_ shot: MissionShotDescriptor) throws {
    guard PackValidation.localID(shot.weapon), shot.velocity.finite,
      (1...100_000).contains(shot.velocity.length), shot.age.isFinite, (0...60).contains(shot.age),
      shot.lifetime.isFinite, (0.01...60).contains(shot.lifetime),
      shot.damage.isFinite, (0.001...100_000).contains(shot.damage),
      shot.radius.isFinite, (0.01...100).contains(shot.radius), shot.collisionDelay.isFinite,
      (0...shot.lifetime).contains(shot.collisionDelay)
    else { throw MissionNativeBridgeError.invalidShot }
  }
}

/// Durable target identity is distinct from a native address allocated for one visit.
public enum MissionLaunchTarget: Equatable, Codable, Sendable {
  case player
  case actor(instance: UUID, actor: UUID, packDigest: String)
}

/// Bounded historical data, never a capability after decoding.
/// MC1 retains this unchanged as ScriptNPCShot.nativeAttribution and revalidates every join.
public struct MissionLaunchArchive: Equatable, Codable, Sendable {
  public let schemaVersion: Int
  public let shotID: UUID
  public let instanceID: UUID
  public let packDigest: String
  public let sourceActorID: UUID
  public let sourceComponentID: UUID?
  public let intendedTarget: MissionLaunchTarget
  public let judgement: MissionLaunchJudgement
  public var origin: AttackOrigin { judgement.origin }

  fileprivate init(
    shotID: UUID, instanceID: UUID, packDigest: String, sourceActorID: UUID,
    sourceComponentID: UUID?, intendedTarget: MissionLaunchTarget,
    judgement: MissionLaunchJudgement
  ) {
    schemaVersion = 1
    self.shotID = shotID
    self.instanceID = instanceID
    self.packDigest = packDigest
    self.sourceActorID = sourceActorID
    self.sourceComponentID = sourceComponentID
    self.intendedTarget = intendedTarget
    self.judgement = judgement
  }

  /// Shape checks do not prove the archive belongs to an actual retained shot.
  public var valid: Bool {
    guard schemaVersion == 1, judgement.valid, origin.owner.entity >= 2,
      origin.playerAmmunition == nil,
      packDigest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
      origin.sourcePart == sourceComponentID?.uuidString
    else { return false }
    switch intendedTarget {
    case .player:
      return judgement.victim.entity == 0
    case .actor(_, _, let digest):
      return judgement.victim.entity >= 2
        && digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
    }
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion, shotID, instanceID, packDigest, sourceActorID, sourceComponentID
    case intendedTarget, judgement
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
    shotID = try values.decode(UUID.self, forKey: .shotID)
    instanceID = try values.decode(UUID.self, forKey: .instanceID)
    packDigest = try values.decode(String.self, forKey: .packDigest)
    sourceActorID = try values.decode(UUID.self, forKey: .sourceActorID)
    sourceComponentID = try values.decodeIfPresent(UUID.self, forKey: .sourceComponentID)
    intendedTarget = try values.decode(MissionLaunchTarget.self, forKey: .intendedTarget)
    judgement = try values.decode(MissionLaunchJudgement.self, forKey: .judgement)
    guard valid else { throw MissionNativeBridgeError.invalidArchive }
  }
}

/// Only a verified same intended durable victim/current binding can use frozen law.
/// Historical source data remains available even when current adjudication is unknown.
enum MissionImpactAttribution: Equatable, Sendable {
  case unknown
  case frozenLaunch
}

/// Mission-shot-only capability for G1's single damage kernel. Not persisted or constructible
/// by native consumers. The actual resolver/geometry producer remains in this provider file.
struct MissionNativeImpactProof: Equatable, Sendable {
  /// Actual finite step segment, clipped to the shot's remaining lifetime (at most 60 seconds).
  let delta: Double
  let physicalTime: Double
  fileprivate let sourceBinding: MissionActorBinding?
  let shot: MissionShotDescriptor
  let archive: MissionLaunchArchive?
  let hit: GameplayHit
  let victimPart: String?
  let victimComponentID: UUID?
  let currentSource: ActorIdentity?
  let currentVictim: ActorIdentity?
  let attribution: MissionImpactAttribution
  let system: SystemIdentity
  let visit: UInt64
  let sceneRevision: UInt64
  let instanceRevision: UInt64
  let projectileBody: SpaceBody
  let targetBody: SpaceBody?
  var damage: Double { shot.damage }
  var kind: AttackKind { .plasma }
  var shotID: UUID { shot.identity }
  var sourceInstanceID: UUID { shot.instance }
  var sourceActorID: UUID { shot.owner }
  var sourceComponentID: UUID? { shot.component }
  var originalOrigin: AttackOrigin? { archive?.origin }
  var frozenJudgement: MissionLaunchJudgement? {
    switch attribution {
    case .unknown: nil
    case .frozenLaunch: archive?.judgement
    }
  }

  fileprivate init(
    delta: Double, physicalTime: Double, sourceBinding: MissionActorBinding?,
    shot: MissionShotDescriptor, archive: MissionLaunchArchive?, hit: GameplayHit,
    victimPart: String?, victimComponentID: UUID?, currentSource: ActorIdentity?,
    currentVictim: ActorIdentity?, attribution: MissionImpactAttribution,
    system: SystemIdentity, visit: UInt64, sceneRevision: UInt64, instanceRevision: UInt64,
    projectileBody: SpaceBody, targetBody: SpaceBody?
  ) {
    self.delta = delta
    self.physicalTime = physicalTime
    self.sourceBinding = sourceBinding
    self.shot = shot
    self.archive = archive
    self.hit = hit
    self.victimPart = victimPart
    self.victimComponentID = victimComponentID
    self.currentSource = currentSource
    self.currentVictim = currentVictim
    self.attribution = attribution
    self.system = system
    self.visit = visit
    self.sceneRevision = sceneRevision
    self.instanceRevision = instanceRevision
    self.projectileBody = projectileBody
    self.targetBody = targetBody
  }
}

extension MissionNativeBridge {
  /// G1's actual fire boundary must re-resolve the source/target factories before this call.
  /// This seals bounded historical data only; it never allocates, fires or creates law facts.
  static func makeLaunchArchive(
    shot: MissionShotDescriptor, source: MissionActorBinding,
    intendedTarget: MissionActorBinding?, judgement: MissionLaunchJudgement
  ) throws -> MissionLaunchArchive {
    try validateShot(shot)
    guard judgement.valid, shot.owner == source.actorID, shot.instance == source.instanceID,
      judgement.origin.owner == source.nativeActor,
      judgement.origin.sourcePart == shot.component?.uuidString
    else { throw MissionNativeBridgeError.invalidArchive }
    let target: MissionLaunchTarget
    if let intendedTarget {
      guard judgement.victim == intendedTarget.nativeActor else {
        throw MissionNativeBridgeError.invalidArchive
      }
      target = .actor(
        instance: intendedTarget.instanceID, actor: intendedTarget.actorID,
        packDigest: intendedTarget.descriptor.packDigest)
    } else {
      guard judgement.victim.entity == 0 else { throw MissionNativeBridgeError.invalidArchive }
      target = .player
    }
    let archive = MissionLaunchArchive(
      shotID: shot.identity, instanceID: source.instanceID,
      packDigest: source.descriptor.packDigest, sourceActorID: source.actorID,
      sourceComponentID: shot.component, intendedTarget: target, judgement: judgement)
    guard archive.valid else { throw MissionNativeBridgeError.invalidArchive }
    return archive
  }

  /// Nil is the old unknown-history case; malformed present evidence never degrades to nil.
  static func validateArchive(
    _ archive: MissionLaunchArchive?, shot: MissionShotDescriptor, packDigest: String
  ) throws {
    try validateShot(shot)
    guard let archive else { return }
    guard archive.valid, archive.shotID == shot.identity, archive.instanceID == shot.instance,
      archive.sourceActorID == shot.owner, archive.sourceComponentID == shot.component,
      archive.packDigest == packDigest
    else { throw MissionNativeBridgeError.invalidArchive }
  }
}

extension Game {
  /// Resolve the actual retained source before sealing its native binding. This read never
  /// adopts a body, allocates an identity, infers a pack or accepts a caller-built descriptor.
  func currentMissionNativeBinding(bodyID: Int) throws -> MissionActorBinding {
    guard let descriptor = currentMissionActorDescriptor(bodyID: bodyID) else {
      throw MissionNativeBridgeError.sourceMismatch
    }
    guard let body = bodies.first(where: { $0.id == bodyID }),
      let context = gameplayContext()
    else { throw MissionNativeBridgeError.invalidNativeBinding }
    return try MissionNativeBridge.bindActor(descriptor: descriptor, body: body, context: context)
  }

  /// Current pack/fit/retained ownership is resolved again, not trusted from an older proof.
  func validateMissionNativeBinding(_ binding: MissionActorBinding) throws {
    guard let descriptor = currentMissionActorDescriptor(bodyID: binding.bodyID),
      let body = bodies.first(where: { $0.id == binding.bodyID }),
      let context = gameplayContext()
    else { throw MissionNativeBridgeError.sourceMismatch }
    try MissionNativeBridge.validateBinding(
      binding, descriptor: descriptor, body: body, context: context)
  }
}

/// Constructed only by the physical query in this file; no damage or custody authority.
struct MissionCollisionContact: Equatable, Sendable {
  let hit: GameplayHit
  let victimPart: String?
  let componentUUID: UUID?
  let selectedTargetBody: SpaceBody?
  fileprivate let selection: MissionCollisionQueryGeometry?
  var selectedGeometry: MissionCollisionQueryGeometry? { selection }
  let selectedEmitter: ActorIdentity?
  let selectedLaunch: Vector3?
  let nativeCurveObservation: CurrentNewtOrdnanceCurveContact?
  fileprivate init(hit: GameplayHit, victimPart: String?, componentUUID: UUID?, body: SpaceBody?,
    selection: MissionCollisionQueryGeometry? = nil,
    emitter: ActorIdentity? = nil, launch: Vector3? = nil,
    curve: CurrentNewtOrdnanceCurveContact? = nil) {
    self.hit = hit
    self.victimPart = victimPart
    self.componentUUID = componentUUID
    self.selectedTargetBody = body
    self.selection = selection
    selectedEmitter = emitter; selectedLaunch = launch
    nativeCurveObservation = curve
  }
}

extension Game {
  /// Inputs and returned points use the current camera-relative physical frame.
  @inline(never)
  func nearestMissionCollision(
    from origin: Vector3, direction: Vector3, range: Double, radius: Double,
    excludingBodyIDs: Set<Int> = [], includePlayer: Bool
  ) throws -> MissionCollisionContact? {
    try requireQualifiedOriginalHullClaims()
    return try nearestQualifiedMissionCollision(from: origin, direction: direction, range: range,
      radius: radius, excludingBodyIDs: excludingBodyIDs, includePlayer: includePlayer)
  }

  @inline(never)
  private func nearestQualifiedMissionCollision(
    from origin: Vector3, direction: Vector3, range: Double, radius: Double,
    excludingBodyIDs: Set<Int>, includePlayer: Bool
  ) throws -> MissionCollisionContact? {
    let geometry = try captureQualifiedMissionCollisionGeometry(path: nil)
    return try geometry.nearestCollision(from: origin,
      direction: direction, range: range, radius: radius,
      excludingBodyIDs: excludingBodyIDs, includePlayer: includePlayer)
  }

  /// Capture only the actual source scene. A sealed native outer path chooses
  /// the old work/manual camera policy; no Game is projected or rewound.
  @inline(never)
  func prepareSelectedNPCBeamGeometry(for path: CurrentNewtOuterMotion)
    throws -> MissionCollisionQueryGeometry
  {
    guard path.startTime == storedFlightSimulation().physicalTime,
      path.epoch == nativeStationRuntimeEpoch,
      path.motion.start == storedFlightSimulation().pose
    else { throw MissionNativeBridgeError.sourceMismatch }
    try requireQualifiedOriginalHullClaims()
    return try captureQualifiedMissionCollisionGeometry(path: path)
  }

  // The selected live-scene entry retains the same full claims-before-capture gate.
  @inline(never)
  private func captureMissionCollisionGeometry(path: CurrentNewtOuterMotion?)
    throws -> MissionCollisionQueryGeometry
  {
    try requireQualifiedOriginalHullClaims()
    return try captureQualifiedMissionCollisionGeometry(path: path)
  }

  private final class MissionCollisionCaptureFrame {
    let opening: FlightSimulationState
    let frame: ShipPose
    let projected: [SpaceBody]
    let sky: [CelestialBody]
    init(opening: FlightSimulationState, frame: ShipPose, projected: [SpaceBody], sky: [CelestialBody]) {
      self.opening = opening; self.frame = frame; self.projected = projected; self.sky = sky
    }
  }

  @inline(never)
  private func missionCollisionCaptureFrame(path: CurrentNewtOuterMotion?) -> MissionCollisionCaptureFrame {
    let opening = storedFlightSimulation()
    let frame = path.map { $0.workMode ? $0.motion.start : $0.motion.end } ?? opening.pose
    let projected: [SpaceBody]
    if let path, !path.workMode { projected = currentNewtPostCameraBodies(path) }
    else { projected = bodies }
    var sky = celestials
    if frame != opening.pose {
      for index in sky.indices {
        sky[index].position = frame.shipPoint(opening.pose.systemPoint(celestials[index].position))
      }
    }
    return .init(opening: opening, frame: frame, projected: projected, sky: sky)
  }

  @inline(never)
  private func captureQualifiedMissionCollisionGeometry(path: CurrentNewtOuterMotion?)
    throws -> MissionCollisionQueryGeometry
  {
    let capture = missionCollisionCaptureFrame(path: path)
    var compounds: [Int: [Mesh]] = [:]
    var custom: [Int: MissionCollisionQueryModels] = [:]
    var swept: [Int: Mesh] = [:]
    try bodies.withUnsafeBufferPointer { stored in
      for index in stored.indices {
        let body = stored.baseAddress!.advanced(by: index)
        guard body.pointee.energy > 0 else { continue }
        try appendCurrentNewtCollisionGeometry(for: body.pointee, to: &compounds)
        appendAuthoredMissionCollisionGeometry(for: body.pointee, to: &custom)
        swept[body.pointee.id] = gameplayMesh(for: body.pointee)
      }
    }
    return .init(opening: capture.opening, bodies: bodies, epoch: nativeStationRuntimeEpoch,
      path: path, frame: capture.frame, projected: capture.projected, playerMesh: nativeGuidanceStoredPlayerMesh(),
      celestials: capture.sky, overrides: gameplayMeshOverrides, compounds: compounds,
      custom: custom, swept: swept)
  }

  @inline(never)
  private func appendCurrentNewtCollisionGeometry(
    for body: borrowing SpaceBody, to compounds: inout [Int: [Mesh]]
  ) throws {
    if let parts = try currentNewtGeometryComponents(for: body) {
      let model = modelPose(of: body)
      compounds[body.id] = parts.compactMap { $0.collisionMesh(relativeTo: model) }
    }
  }

  @inline(never)
  private func appendAuthoredMissionCollisionGeometry(
    for body: borrowing SpaceBody, to custom: inout [Int: MissionCollisionQueryModels]
  ) {
    if let npc = body.scriptNPC {
      var components: [String: Mesh] = [:]
      if npc.valid {
        for spec in npc.fit.definition.components ?? [] where spec.solid {
          if let mesh = scriptModel(spec.model, fit: npc.fit) { components[spec.id] = mesh }
        }
      }
      custom[body.id] = .init(valid: npc.valid,
        root: npc.valid ? scriptModel(npc.fit.definition.model, fit: npc.fit) : nil,
        components: components)
    }
  }
}

/// Read-only physical/source facts for resource and event-capacity planning. This query carries
/// no emission identity or damage authority and can only be constructed by the actual provider.
struct MissionNativeLaserQuery: Sendable {
  let source: MissionActorBinding
  let weapon: MissionWeaponDescriptor
  let sourceComponentID: UUID?
  let contact: MissionCollisionContact?
  let context: EncounterContext

  fileprivate init(
    source: MissionActorBinding, weapon: MissionWeaponDescriptor, component: UUID?,
    contact: MissionCollisionContact?, context: EncounterContext
  ) {
    self.source = source
    self.weapon = weapon
    sourceComponentID = component
    self.contact = contact
    self.context = context
  }
}

/// Current-visit instant emission. A miss remains a real laser discharge without inventing a shot.
struct MissionNativeLaserProof: Sendable {
  let source: MissionActorBinding
  let weapon: MissionWeaponDescriptor
  let sourceComponentID: UUID?
  let origin: AttackOrigin
  let contact: MissionCollisionContact?
  let system: SystemIdentity
  let visit: UInt64
  let sceneRevision: UInt64
  let instanceRevision: UInt64
  var kind: AttackKind { .laser }
  var damage: Double { weapon.damage }
  var hit: GameplayHit? { contact?.hit }
  var victimPart: String? { contact?.victimPart }
  var victimComponentID: UUID? { contact?.componentUUID }
  var targetBody: SpaceBody? { contact?.selectedTargetBody }
  var sourceInstanceID: UUID { source.instanceID }
  var sourceActorID: UUID { source.actorID }

  fileprivate init(
    source: MissionActorBinding, weapon: MissionWeaponDescriptor, component: UUID?,
    origin: AttackOrigin, contact: MissionCollisionContact?, context: EncounterContext
  ) {
    self.source = source
    self.weapon = weapon
    sourceComponentID = component
    self.origin = origin
    self.contact = contact
    system = context.system
    visit = context.visit
    sceneRevision = context.revision
    instanceRevision = source.descriptor.instanceRevision
  }
}

extension Game {
  /// Resolve actual source, weapon and nearest contact without allocating an emission.
  func queryMissionNativeLaser(
    sourceBodyID: Int, weapon: ScriptNPCWeapon, component: UUID?,
    muzzle: Vector3, direction: Vector3
  ) throws -> MissionNativeLaserQuery {
    guard let context = gameplayContext() else {
      throw MissionNativeBridgeError.invalidNativeBinding
    }
    let source = try resolveMissionNativeBinding(bodyID: sourceBodyID, context: context)
    guard
      let actual = missionWeaponDescriptor(
        weapon, source: source.descriptor.body, component: component,
        muzzle: muzzle, direction: direction), actual.kind == .laser
    else { throw MissionNativeBridgeError.unsupportedWeapon }
    let contact = try nearestMissionCollision(
      from: actual.muzzle, direction: actual.direction, range: actual.range, radius: 0,
      excludingBodyIDs: [sourceBodyID], includePlayer: true)
    return .init(
      source: source, weapon: actual, component: component, contact: contact, context: context)
  }

  /// Called within the fire turn after the actual gun's resource preflight. Collision and durable
  /// joins can refuse before the native emission allocator is touched; no simulated shot is made.
  mutating func makeMissionNativeLaserProof(
    sourceBodyID: Int, weapon: ScriptNPCWeapon, component: UUID?,
    muzzle: Vector3, direction: Vector3
  ) throws -> MissionNativeLaserProof {
    let query = try queryMissionNativeLaser(
      sourceBodyID: sourceBodyID, weapon: weapon, component: component,
      muzzle: muzzle, direction: direction)
    guard commander.flightSimulation.valid,
      commander.flightSimulation.nextEmission < UInt64.max
    else { throw MissionNativeBridgeError.unsupportedWeapon }
    // Use the native allocator directly after every fallible physical/source check. Unlike the
    // general adoption helper, this path must not adopt unrelated bodies while sealing a hit.
    guard let emission = commander.flightSimulation.allocateEmission() else {
      throw MissionNativeBridgeError.invalidNativeBinding
    }
    let origin = AttackOrigin(
      emissionID: emission, owner: query.source.nativeActor, emittedAt: query.context.physicalTime,
      ownerLegalAtEmission: query.source.actorSnapshot.legal,
      sourcePart: query.sourceComponentID?.uuidString)
    return .init(
      source: query.source, weapon: query.weapon, component: query.sourceComponentID,
      origin: origin, contact: query.contact, context: query.context)
  }
}

extension Game {
  /// Derive an impact only from the actual live shot, retained record and this step's motion.
  /// It never accepts caller-selected damage, a target index or a historical native owner.
  func missionNativeImpactProof(projectileID: UUID, delta: Double) throws
    -> MissionNativeImpactProof?
  {
    guard delta.isFinite, delta > 0,
      let body = bodies.first(where: { $0.scriptShot?.identity == projectileID }),
      bodies.lazy.filter({ $0.scriptShot?.identity == projectileID }).count == 1,
      bodies.lazy.filter({ $0.id == body.id }).count == 1,
      let shot = body.scriptShot, let descriptor = shot.missionDescriptor,
      let record = commander.scriptState.projectiles[projectileID], record.valid,
      commander.scriptState.projectileArchiveValid(record),
      record.presence == .present, record.body.id == body.id,
      record.galaxy == commander.galaxy, record.system == commander.system,
      let retained = record.body.scriptShot,
      retained.identity == shot.identity, retained.owner == shot.owner,
      retained.instance == shot.instance, retained.weapon == shot.weapon,
      retained.component == shot.component, retained.lifetime == shot.lifetime,
      abs(retained.velocity.length - shot.velocity.length)
        <= max(1, max(retained.velocity.length, shot.velocity.length)) * 1e-6,
      retained.damage == shot.damage, retained.radius == shot.radius,
      retained.collisionDelay == shot.collisionDelay,
      retained.nativeAttribution == shot.nativeAttribution,
      let instance = commander.scriptState.instances[shot.instance], instance.id == shot.instance,
      let context = gameplayContext(), let physical = body.physical,
      physical.population == .projectile, physical.npc == nil, physical.ordnance == nil,
      physical.spawnIdentity?.system == context.system,
      physical.spawnIdentity?.visit == context.visit,
      physical.spawnIdentity?.producer == .ordnance,
      physical.attackOrigin == shot.nativeAttribution?.origin,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      physical.identity.entity >= 2, physical.identity.entity < UInt64.max,
      bodies.lazy.filter({ $0.physical?.identity == physical.identity }).count == 1,
      body.hull == .missile, body.scriptNPC == nil,
      body.missionActorID == nil, body.missionInstanceID == nil,
      body.energy.isFinite, body.energy > 0, body.position.finite
    else { throw MissionNativeBridgeError.invalidShot }
    try MissionNativeBridge.validateArchive(
      shot.nativeAttribution, shot: descriptor, packDigest: instance.digest)
    if let archive = shot.nativeAttribution {
      // Archive shape is context-free. Its historical emission must also be possible in the
      // actual persisted native clock before this producer can grant an impact capability.
      guard archive.origin.owner.system == context.system,
        context.physicalTime.isFinite, context.physicalTime >= 0,
        archive.origin.emittedAt <= context.physicalTime
      else { throw MissionNativeBridgeError.invalidArchive }
    }
    // Stored pose, velocity and age may be older or in the station frame. Immutable source and
    // tuning join above; motion below comes exclusively from the current physical shot.
    let movement = OuterScriptProjectileTranslation(position: body.position,
      velocity: shot.velocity, age: shot.age, lifetime: shot.lifetime,
      collisionDelay: shot.collisionDelay, delta: delta)
    let duration = movement.duration
    guard let origin = movement.collisionStart, let range = movement.collisionRange else { return nil }
    let ownerBodies = bodies.filter {
      $0.missionInstanceID == shot.instance && $0.missionActorID == shot.owner && $0.energy > 0
    }
    let source: MissionActorBinding?
    if ownerBodies.count == 1 {
      source = try? resolveMissionNativeBinding(bodyID: ownerBodies[0].id, context: context)
    } else {
      source = nil
    }
    var excluded: Set<Int> = [body.id]
    if let source { excluded.insert(source.bodyID) }
    let direction = shot.velocity.unit
    guard
      let contact = try nearestMissionCollision(
        from: origin, direction: direction, range: range, radius: shot.radius,
        excludingBodyIDs: excluded, includePlayer: true)
    else { return nil }
    let victim: ActorIdentity?
    let targetBinding: MissionActorBinding?
    switch contact.hit.target {
    case .player:
      victim = context.player.identity
      targetBinding = nil
    case .body(let id):
      guard let identity = contact.selectedTargetBody?.physical?.identity,
        identity.system == context.system, identity.visit == context.visit,
        context.actors.filter({ $0.identity == identity }).count == 1
      else { throw MissionNativeBridgeError.invalidNativeBinding }
      victim = identity
      targetBinding = try? resolveMissionNativeBinding(bodyID: id, context: context)
    case .celestial:
      victim = nil
      targetBinding = nil
    }
    var attribution = MissionImpactAttribution.unknown
    if source != nil, let archive = shot.nativeAttribution {
      switch archive.intendedTarget {
      case .player:
        if case .player = contact.hit.target { attribution = .frozenLaunch }
      case .actor(let targetInstance, let targetActor, let digest):
        if let targetBinding,
          targetBinding.instanceID == targetInstance, targetBinding.actorID == targetActor,
          targetBinding.descriptor.packDigest == digest
        {
          attribution = .frozenLaunch
        }
      }
    }
    return .init(
      delta: duration, physicalTime: context.physicalTime, sourceBinding: source,
      shot: descriptor, archive: shot.nativeAttribution, hit: contact.hit,
      victimPart: contact.victimPart, victimComponentID: contact.componentUUID,
      currentSource: source?.nativeActor, currentVictim: victim, attribution: attribution,
      system: context.system, visit: context.visit, sceneRevision: context.revision,
      instanceRevision: instance.revision, projectileBody: body,
      targetBody: contact.selectedTargetBody)
  }
}

extension Game {
  /// The physical producer supplies the one actual context captured within its actor turn.
  /// Kept private so a caller-built context cannot become mission authority.
  private func resolveMissionNativeBinding(bodyID: Int, context: EncounterContext) throws
    -> MissionActorBinding
  {
    guard let descriptor = currentMissionActorDescriptor(bodyID: bodyID),
      let body = bodies.first(where: { $0.id == bodyID })
    else { throw MissionNativeBridgeError.sourceMismatch }
    return try MissionNativeBridge.bindActor(descriptor: descriptor, body: body, context: context)
  }
}

extension Game {
  /// Re-query the sealed bounded step against current retained/native facts. No counters,
  /// bodies, law, gun resources or event queues are changed by capability validation.
  func validateMissionNativeImpactProof(_ proof: MissionNativeImpactProof) throws {
    guard proof.delta.isFinite, proof.delta > 0, proof.delta <= 60,
      proof.physicalTime.isFinite, proof.physicalTime >= 0
    else { throw MissionNativeBridgeError.staleBinding }
    do {
      guard
        let current = try missionNativeImpactProof(
          projectileID: proof.shotID, delta: proof.delta), current == proof
      else { throw MissionNativeBridgeError.staleBinding }
    } catch {
      throw MissionNativeBridgeError.staleBinding
    }
  }

  /// An already allocated instant emission is checked without calling its allocating producer.
  /// The kernel independently consumes its current-visit emission watermark on successful apply.
  func validateMissionNativeLaserProof(_ proof: MissionNativeLaserProof) throws {
    do {
      guard let context = gameplayContext(),
        proof.system == context.system, proof.visit == context.visit,
        proof.sceneRevision == context.revision, proof.origin.emittedAt == context.physicalTime,
        context.physicalTime.isFinite, context.physicalTime >= 0,
        proof.origin.owner == proof.source.nativeActor,
        proof.origin.ownerLegalAtEmission == proof.source.actorSnapshot.legal,
        proof.origin.sourcePart == proof.sourceComponentID?.uuidString,
        proof.origin.ordnance == nil, proof.origin.playerAmmunition == nil,
        proof.origin.emissionID > 0, proof.origin.emissionID < UInt64.max,
        proof.origin.emissionID + 1 == commander.flightSimulation.nextEmission,
        proof.instanceRevision == proof.source.descriptor.instanceRevision
      else { throw MissionNativeBridgeError.staleBinding }
      let source = try resolveMissionNativeBinding(bodyID: proof.source.bodyID, context: context)
      guard source == proof.source, let npc = source.descriptor.body.scriptNPC else {
        throw MissionNativeBridgeError.staleBinding
      }
      let weapon: ScriptNPCWeapon?
      if let component = proof.sourceComponentID {
        guard let alias = npc.components.first(where: { $0.value.identity == component })?.key
        else { throw MissionNativeBridgeError.staleBinding }
        weapon = npc.fit.definition.components?.first(where: { $0.id == alias })?
          .weapons?.first(where: { $0.id == proof.weapon.id })
      } else {
        weapon = npc.fit.definition.lasers?.first(where: { $0.id == proof.weapon.id })
      }
      guard let weapon,
        let current = missionWeaponDescriptor(
          weapon, source: source.descriptor.body, component: proof.sourceComponentID,
          muzzle: proof.weapon.muzzle, direction: proof.weapon.direction),
        current.kind == .laser, current == proof.weapon
      else { throw MissionNativeBridgeError.staleBinding }
      let contact = try nearestMissionCollision(
        from: current.muzzle, direction: current.direction, range: current.range, radius: 0,
        excludingBodyIDs: [source.bodyID], includePlayer: true)
      guard contact == proof.contact else { throw MissionNativeBridgeError.staleBinding }
    } catch {
      throw MissionNativeBridgeError.staleBinding
    }
  }
}

extension Game {
  /// One synchronous projectile step. The native kernel owns impact effects; this caller
  /// projects its receipt exactly once before the central frame culls bodies or drains events.
  @discardableResult
  mutating func stepMissionNativeProjectile(projectileID: UUID, delta: Double) throws
    -> NativeMissionImpactReceipt?
  {
    guard delta.isFinite, delta > 0, commander.flightSimulation.physicalTime.isFinite,
      commander.flightSimulation.physicalTime >= 0
    else { throw MissionNativeBridgeError.invalidShot }
    guard let index = bodies.firstIndex(where: { $0.scriptShot?.identity == projectileID }),
      bodies[index].energy > 0
    else { return nil }
    if let proof = try missionNativeImpactProof(projectileID: projectileID, delta: delta) {
      let speed = proof.shot.velocity.length
      let elapsed =
        max(0, proof.shot.collisionDelay - proof.shot.age)
        + proof.hit.distance / speed
      let age = min(proof.shot.lifetime, proof.shot.age + elapsed)
      guard age.isFinite, proof.hit.point.finite else {
        throw MissionNativeBridgeError.invalidShot
      }
      let receipt = try applyMissionImpact(proof)
      projectScriptMissionImpact(receipt)
      // Preserve kernel effects and any projection changes; only locate the terminal shot's
      // actual contact and age, rather than writing an older body snapshot over native state.
      if let terminal = bodies.firstIndex(where: { $0.scriptShot?.identity == projectileID }) {
        bodies[terminal].position = proof.hit.point
        bodies[terminal].scriptShot?.age = age
      }
      return receipt
    }
    // A no-contact producer result has already validated retained/native joins, archive time
    // and the actual physical shot. Stage its bounded movement before changing the live body.
    guard let shot = bodies[index].scriptShot else { throw MissionNativeBridgeError.invalidShot }
    let movement = OuterScriptProjectileTranslation(position: bodies[index].position,
      velocity: shot.velocity, age: shot.age, lifetime: shot.lifetime,
      collisionDelay: shot.collisionDelay, delta: delta)
    let position = movement.end
    let age = movement.age
    let velocity = commander.flightSimulation.pose.orientation.apply(shot.velocity)
    guard position.finite, position.length.isFinite, age.isFinite, velocity.finite else {
      throw MissionNativeBridgeError.invalidShot
    }
    bodies[index].position = position
    bodies[index].scriptShot?.age = age
    bodies[index].physical?.velocity = velocity
    if age >= shot.lifetime {
      bodies[index].energy = 0
      recordScriptShotRemoval(bodies[index])
    }
    return nil
  }
}

private struct MissionReadyGun {
  let bodyID: Int
  let bodyIndex: Int
  let owner: UUID
  let instance: UUID
  let component: UUID?
  let componentAlias: String?
  let weapon: ScriptNPCWeapon
  let gun: ScriptNPCGunState
  let muzzle: Vector3
  let direction: Vector3
  let nextShot: UInt64
  let intendedTarget: GameplayHitTarget
}

extension Game {
  /// Typed current-gun entry point used by the frame loop. A successful plasma discharge
  /// returns no impact receipt; its actual retained projectile carries the later effect.
  @discardableResult
  mutating func fireMissionNativeWeapon(bodyID: Int, weaponID: String, componentID: UUID?) throws
    -> NativeMissionImpactReceipt?
  {
    guard
      let ready = try withReadOnlyCommander({ [bodies] commander in
        try Self.readyMissionGun(
          bodyID: bodyID, weaponID: weaponID, componentID: componentID, bodies: bodies,
          commander: commander)
      })
    else { return nil }
    switch ready.weapon.kind {
    case .laser:
      return try fireMissionNativeLaser(
        bodyID: bodyID, weaponID: weaponID, componentID: componentID)
    case .plasma:
      try fireMissionNativePlasma(ready)
      return nil
    }
  }

  /// Keep projectile preparation temporaries off the synchronous laser call stack.
  private mutating func fireMissionNativePlasma(_ ready: MissionReadyGun) throws {
    let source = try Self.preflightMissionNativePlasma(&self, ready: ready)
    let plan = try prepareMissionProjectileAdmission(
      source: source, weapon: ready.weapon, component: ready.component,
      muzzle: ready.muzzle, direction: ready.direction, intendedTarget: ready.intendedTarget)
    _ = try commitMissionProjectileAdmission(plan)
    // Admission appends a projectile and preserves the source's index. No fallible work
    // remains between the native commit and the selected gun debit/firing event.
    commitMissionGun(ready, gun: ready.gun)
  }

  /// End binding and event-preflight copies before the deeper projectile admission phase.
  private static func preflightMissionNativePlasma(_ game: inout Game, ready: MissionReadyGun)
    throws -> MissionActorBinding
  {
    let source = try game.currentMissionNativeBinding(bodyID: ready.bodyID)
    _ = try game.planScriptMissionImpactEvents(
      target: nil, damage: 0, damageAdmitted: false, victimPart: nil,
      victimComponentID: nil, componentDestroyed: false, hullDestroyed: false,
      sourceWeaponInstanceID: ready.instance)
    return source
  }

  /// The frame loop owns cooling and aim. This synchronous boundary owns final resource
  /// preflight, actual native effect, selected gun debit and the one firing event.
  @discardableResult
  mutating func fireMissionNativeLaser(bodyID: Int, weaponID: String, componentID: UUID?) throws
    -> NativeMissionImpactReceipt?
  {
    guard
      let ready = try withReadOnlyCommander({ [bodies] commander in
        try Self.readyMissionGun(
          bodyID: bodyID, weaponID: weaponID, componentID: componentID, bodies: bodies,
          commander: commander)
      })
    else { return nil }
    guard ready.weapon.kind == .laser else { throw MissionNativeBridgeError.unsupportedWeapon }
    let query = try queryMissionNativeLaser(
      sourceBodyID: bodyID, weapon: ready.weapon, component: componentID,
      muzzle: ready.muzzle, direction: ready.direction)
    _ = try preflightMissionNativeLaser(query)
    // Only the producer's small native emission allocation precedes the kernel. The kernel
    // stages every fallible effect; restore that allocator if it refuses, without a Game copy.
    let flight = commander.flightSimulation
    let proof: MissionNativeLaserProof
    let receipt: NativeMissionImpactReceipt
    do {
      proof = try makeMissionNativeLaserProof(
        sourceBodyID: bodyID, weapon: ready.weapon, component: componentID,
        muzzle: ready.muzzle, direction: ready.direction)
      receipt = try applyMissionImpact(proof)
    } catch {
      commander.flightSimulation = flight
      throw error
    }
    projectScriptMissionImpact(receipt)
    var gun = ready.gun
    gun.beamRange = proof.hit?.distance ?? ready.weapon.range
    commitMissionGun(ready, gun: gun)
    return receipt
  }

  /// Cheap eligibility comes before actual retained factories and the physical collision query.
  /// Identifiers select current authored facts; callers cannot supply damage or gun state.
  private static func readyMissionGun(
    bodyID: Int, weaponID: String, componentID: UUID?, bodies: [SpaceBody],
    commander: borrowing Commander
  ) throws -> MissionReadyGun? {
    guard let bodyIndex = bodies.firstIndex(where: { $0.id == bodyID }) else { return nil }
    let body = bodies[bodyIndex]
    guard body.energy > 0, let npc = body.scriptNPC, let owner = body.missionActorID,
      let instance = body.missionInstanceID
    else { return nil }
    let weapon: ScriptNPCWeapon
    let gun: ScriptNPCGunState
    let pose: Basis3
    let muzzle: Vector3
    let alias: String?
    if let componentID {
      guard let entry = npc.components.first(where: { $0.value.identity == componentID }),
        entry.value.energy > 0,
        let spec = npc.fit.definition.components?.first(where: { $0.id == entry.key }),
        let selected = spec.weapons?.first(where: { $0.id == weaponID }),
        let selectedGun = entry.value.guns[weaponID]
      else { throw MissionNativeBridgeError.unsupportedWeapon }
      weapon = selected
      gun = selectedGun
      alias = entry.key
      pose = spec.orientation.transformed(by: body.orientation)
      muzzle =
        body.position + body.orientation.apply(spec.position * npc.fit.definition.scale)
        + pose.apply(weapon.muzzle * (spec.scale * npc.fit.definition.scale))
    } else {
      guard let selected = npc.fit.definition.lasers?.first(where: { $0.id == weaponID }),
        let selectedGun = npc.guns[weaponID]
      else { throw MissionNativeBridgeError.unsupportedWeapon }
      weapon = selected
      gun = selectedGun
      alias = nil
      pose = body.orientation
      muzzle = body.position + pose.apply(weapon.muzzle * npc.fit.definition.scale)
    }
    guard gun.valid, gun.cooldown <= 0, gun.heat + weapon.heat <= weapon.maximumHeat,
      body.energy > weapon.energy, npc.shots < UInt64(Int64.max) - 1,
      let intent = npc.intent, intent.mode == .attack
    else { return nil }
    let target: Vector3
    let intendedTarget: GameplayHitTarget
    if intent.player {
      target = Self.nativePlayerSurfaceAim(from: muzzle, mesh: commander.playerMesh)
      intendedTarget = .player
    } else {
      let candidates = bodies.filter { $0.missionActorID == intent.target && $0.energy > 0 }
      guard candidates.count == 1, let actual = candidates.first else { return nil }
      target = actual.position
      intendedTarget = .body(actual.id)
    }
    let difference = target - muzzle
    guard difference.finite, difference.length > 1e-6, difference.length <= weapon.range else {
      return nil
    }
    let desired = pose.inverse(difference.unit)
    let direction = pose.apply(gun.aim ?? weapon.direction).unit
    guard desired.dot(weapon.direction) >= cos(weapon.arc) - 1e-9,
      direction.dot(difference.unit) > 0.999
    else { return nil }
    return .init(
      bodyID: bodyID, bodyIndex: bodyIndex, owner: owner, instance: instance,
      component: componentID,
      componentAlias: alias, weapon: weapon, gun: gun, muzzle: muzzle,
      direction: direction, nextShot: npc.shots + 1, intendedTarget: intendedTarget)
  }

  private mutating func commitMissionGun(_ ready: MissionReadyGun, gun original: ScriptNPCGunState)
  {
    // Kernel and projection never cull the source or mutate its selected gun. Keep their native
    // legal/resource effects and other gun fields rather than restoring an old whole NPC value.
    let index = ready.bodyIndex
    var gun = original
    gun.heat += ready.weapon.heat
    gun.cooldown = ready.weapon.interval
    bodies[index].energy = max(0, bodies[index].energy - ready.weapon.energy)
    if let alias = ready.componentAlias {
      bodies[index].scriptNPC?.components[alias]?.guns[ready.weapon.id] = gun
    } else {
      bodies[index].scriptNPC?.guns[ready.weapon.id] = gun
    }
    bodies[index].scriptNPC?.shots = ready.nextShot
    emitScriptEvent(
      "weapon.fired",
      values: [
        "actor_id": .string(ready.owner.uuidString), "weapon": .string(ready.weapon.id),
        "shot": .integer(Int64(ready.nextShot)),
        "component_id": ready.component.map { .string($0.uuidString) } ?? .null,
      ], only: ready.instance, drain: false)
  }
}


fileprivate struct MissionCollisionQueryModels: Sendable {
  let valid: Bool
  let root: Mesh?
  let components: [String: Mesh]
}

/// Actual captured geometry only. Its private constructor grants no actor,
/// damage, clock, mission binding or selected-target restoration authority.
final class MissionCollisionQueryGeometry: Sendable, Equatable {
  let openingFlight: FlightSimulationState
  let openingBodies: [SpaceBody]
  let epoch: UUID
  let selectedFrame: ShipPose
  private let path: CurrentNewtOuterMotion?
  private let bodies: [SpaceBody]
  private let playerMesh: Mesh
  private let celestials: [CelestialBody]
  private let meshOverrides: [Int: Mesh]
  private let newtComponents: [Int: [Mesh]]
  private let customModels: [Int: MissionCollisionQueryModels]
  private let sweptMeshes: [Int: Mesh]

  static func == (a: MissionCollisionQueryGeometry, b: MissionCollisionQueryGeometry) -> Bool { a === b }

  fileprivate init(opening: FlightSimulationState, bodies: [SpaceBody], epoch: UUID,
    path: CurrentNewtOuterMotion?, frame: ShipPose, projected: [SpaceBody], playerMesh: Mesh,
    celestials: [CelestialBody], overrides: [Int: Mesh], compounds: [Int: [Mesh]],
    custom: [Int: MissionCollisionQueryModels], swept: [Int: Mesh]) {
    openingFlight = opening; openingBodies = bodies; self.epoch = epoch; self.path = path
    selectedFrame = frame; self.bodies = projected; self.playerMesh = playerMesh
    self.celestials = celestials; meshOverrides = overrides; newtComponents = compounds
    customModels = custom; sweptMeshes = swept
  }

  func matchesOpening(flight: FlightSimulationState, bodies: [SpaceBody], epoch: UUID) -> Bool {
    openingFlight == flight && openingBodies == bodies && self.epoch == epoch
  }

  func isForPath(_ other: CurrentNewtOuterMotion) -> Bool { path === other }

  var hasSelectedPath: Bool { path != nil }
  var selectedDuration: Double? { path?.motion.duration }

  func selectedBody(id: Int) -> SpaceBody? {
    let selected = bodies.filter { $0.id == id }
    return selected.count == 1 ? selected[0] : nil
  }

  func playerSurfaceAim(from origin: Vector3) -> Vector3 {
    Game.nativePlayerSurfaceAim(from: origin, mesh: playerMesh)
  }

  @inline(never)
  fileprivate func currentScene(live: MissionCollisionQueryGeometry,
    poses: [ActorIdentity: ShipPose], components: [ActorIdentity: [CurrentNewtKitComponent]],
    source: ActorIdentity) throws -> MissionCollisionQueryGeometry
  {
    guard let path, let sourceIndex = openingBodies.firstIndex(where: { $0.physical?.identity == source }),
      live.epoch == epoch, live.openingFlight.system == openingFlight.system,
      live.openingFlight.visit == openingFlight.visit
    else { throw MissionNativeBridgeError.sourceMismatch }
    var scene: [SpaceBody] = []
    var compounds: [Int: [Mesh]] = [:]
    var models = customModels
    var overrides = meshOverrides
    var swept = sweptMeshes
    for current in live.openingBodies where current.energy > 0 {
      guard let actor = current.physical?.identity, let pose = poses[actor] else {
        throw MissionNativeBridgeError.sourceMismatch
      }
      let oldIndex = openingBodies.firstIndex(where: { $0.physical?.identity == actor })
      let old = oldIndex.map { openingBodies[$0] }
      if let old {
        guard old.id == current.id, old.hull == current.hull,
          old.physical?.catalogueShipID == current.physical?.catalogueShipID,
          old.missionActorID == current.missionActorID, old.missionInstanceID == current.missionInstanceID,
          old.scriptNPC?.fit == current.scriptNPC?.fit,
          old.scriptNPC?.components.mapValues(\.identity) == current.scriptNPC?.components.mapValues(\.identity)
        else { throw MissionNativeBridgeError.sourceMismatch }
      }
      var body = old ?? current
      body.energy = current.energy
      body.scriptNPC = current.scriptNPC
      body.position = selectedFrame.shipPoint(pose.position)
      body.orientation = pose.orientation.relative(to: selectedFrame.orientation)
      body.rotation = 0
      scene.append(body)
      if let parts = components[actor] {
        guard !parts.isEmpty, parts.allSatisfy(\.validForCurrentNewtQuery),
          Set(parts.map(\.id)).count == parts.count else { throw MissionNativeBridgeError.invalidGeometry }
        compounds[body.id] = parts.compactMap { $0.collisionMesh(relativeTo: pose) }
      } else if body.physical?.currentNewtKitStock != nil || body.physical?.currentNewtKitReceipt != nil {
        throw MissionNativeBridgeError.sourceMismatch
      }
      // The old manual loop had advanced preceding bodies. Work planning had
      // advanced only its preceding hostile pursuit actors, never the fittings.
      let advancedGeometry = oldIndex.map { !path.workMode && $0 < sourceIndex } ?? true
      if advancedGeometry {
        models[current.id] = live.customModels[current.id]
        overrides[current.id] = live.meshOverrides[current.id]
        swept[current.id] = live.sweptMeshes[current.id]
      }
    }
    return .init(opening: openingFlight, bodies: openingBodies, epoch: epoch, path: path,
      frame: selectedFrame, projected: scene, playerMesh: playerMesh, celestials: celestials,
      overrides: overrides, compounds: compounds, custom: models, swept: swept)
  }

  func nearestCollision(
    from origin: Vector3, direction: Vector3, range: Double, radius: Double,
    excludingBodyIDs: Set<Int> = [], includePlayer: Bool
  ) throws -> MissionCollisionContact? {
    try query(from: origin, direction: direction, range: range, radius: radius,
      excludingBodyIDs: excludingBodyIDs, includePlayer: includePlayer, emitter: nil, launch: nil)
  }

  @inline(never)
  fileprivate func query(
    from origin: Vector3, direction: Vector3, range: Double, radius: Double,
    excludingBodyIDs: Set<Int>, includePlayer: Bool,
    emitter: ActorIdentity?, launch: Vector3?
  ) throws -> MissionCollisionContact? {
    func finite(_ vector: Vector3) -> Bool { vector.finite && vector.length.isFinite }
    guard finite(origin), finite(direction), abs(direction.length - 1) <= 1e-6,
      range.isFinite, range > 0, radius.isFinite, radius >= 0
    else { throw MissionNativeBridgeError.invalidGeometry }
    // Native zero-radius mesh rays own normalization and their authoritative hit point.
    let nativeDirection = direction
    let direction = direction.unit
    guard finite(origin + direction * range) else { throw MissionNativeBridgeError.invalidGeometry }
    var nearest: MissionCollisionContact?
    func rank(_ contact: MissionCollisionContact) -> (Int, Int, String) {
      switch contact.hit.target {
      case .body(let id): return (1, id, contact.victimPart ?? "")
      case .player: return (2, 0, "")
      case .celestial(.planet): return (0, 0, "")
      case .celestial(.sun): return (0, 1, "")
      }
    }
    func consider(
      _ distance: Double, target: GameplayHitTarget, body: SpaceBody? = nil,
      part: String? = nil, component: UUID? = nil, nativePoint: Vector3? = nil
    ) {
      guard distance.isFinite, (0...range).contains(distance) else { return }
      let point = nativePoint ?? (origin + direction * distance)
      guard finite(point) else { return }
      let candidate = MissionCollisionContact(
        hit: .init(target: target, distance: distance, point: point),
        victimPart: part, componentUUID: component, body: body,
        selection: emitter == nil ? nil : self, emitter: emitter, launch: launch)
      if let previous = nearest {
        guard
          distance < previous.hit.distance
            || (distance == previous.hit.distance && rank(candidate) < rank(previous))
        else { return }
      }
      nearest = candidate
    }
    // The native ray path accepts rounded nonplanar polygons and skips individual
    // degenerate faces. Project into the same dominant axis to select ears, retaining the
    // original 3D vertices for the sweep instead of flattening authored geometry.
    func prepare(_ mesh: Mesh) throws -> [[Int]] {
      guard !mesh.vertices.isEmpty, !mesh.faces.isEmpty, mesh.vertices.allSatisfy(finite),
        mesh.faces.allSatisfy({
          $0.count >= 3 && $0.allSatisfy(mesh.vertices.indices.contains)
        })
      else { throw MissionNativeBridgeError.invalidGeometry }
      var result: [[Int]] = []
      var usableFaces = 0
      for face in mesh.faces {
        var polygon = face
        if polygon.first == polygon.last { polygon.removeLast() }
        let first = mesh.vertices[polygon[0]]
        guard
          let normal = (1..<(polygon.count - 1)).lazy.map({
            (mesh.vertices[polygon[$0]] - first).cross(mesh.vertices[polygon[$0 + 1]] - first)
          }).first(where: { $0.length > 0 })
        else { continue }
        guard finite(normal) else { throw MissionNativeBridgeError.invalidGeometry }
        usableFaces += 1
        // Exact zero-radius intersections use native authored-polygon clipping, not ear clips.
        if radius == 0 { continue }
        guard Set(polygon).count == polygon.count else {
          throw MissionNativeBridgeError.invalidGeometry
        }
        let scale = polygon.map { (mesh.vertices[$0] - first).length }.max() ?? 0
        guard scale.isFinite, scale > 0 else { throw MissionNativeBridgeError.invalidGeometry }
        let points = Dictionary(
          uniqueKeysWithValues: polygon.map {
            ($0, (mesh.vertices[$0] - first) * (1 / scale))
          })
        guard points.values.allSatisfy(finite) else {
          throw MissionNativeBridgeError.invalidGeometry
        }
        let axis = [abs(normal.x), abs(normal.y), abs(normal.z)].enumerated().max {
          $0.element < $1.element
        }!.offset
        func point(_ index: Int) -> (Double, Double) {
          let v = points[index]!
          return axis == 0 ? (v.y, v.z) : axis == 1 ? (v.x, v.z) : (v.x, v.y)
        }
        func cross(_ a: Int, _ b: Int, _ c: Int) -> Double {
          let p = point(a)
          let q = point(b)
          let r = point(c)
          return (q.0 - p.0) * (r.1 - p.1) - (q.1 - p.1) * (r.0 - p.0)
        }
        // Reject crossing edges rather than filling a malformed polygon's overlapping regions.
        for edge in polygon.indices {
          let next = (edge + 1) % polygon.count
          for other in polygon.indices where other > edge {
            let otherNext = (other + 1) % polygon.count
            if next == other || otherNext == edge { continue }
            let a = polygon[edge]
            let b = polygon[next]
            let c = polygon[other]
            let d = polygon[otherNext]
            let abC = cross(a, b, c)
            let abD = cross(a, b, d)
            let cdA = cross(c, d, a)
            let cdB = cross(c, d, b)
            if ((abC > 0 && abD < 0) || (abC < 0 && abD > 0))
              && ((cdA > 0 && cdB < 0) || (cdA < 0 && cdB > 0))
            {
              throw MissionNativeBridgeError.invalidGeometry
            }
          }
        }
        let area = polygon.indices.reduce(0.0) { total, index in
          let p = point(polygon[index])
          let q = point(polygon[(index + 1) % polygon.count])
          return total + p.0 * q.1 - q.0 * p.1
        }
        guard area.isFinite, area != 0 else { throw MissionNativeBridgeError.invalidGeometry }
        let sign = area > 0 ? 1.0 : -1.0
        let convex = polygon.indices.allSatisfy { index in
          cross(
            polygon[(index + polygon.count - 1) % polygon.count],
            polygon[index], polygon[(index + 1) % polygon.count]) * sign >= 0
        }
        if convex {
          // Preserve the native fan's diagonal and original warped surface on convex faces.
          for index in 1..<(polygon.count - 1) {
            result.append([polygon[0], polygon[index], polygon[index + 1]])
          }
          continue
        }
        // Concave sweeps use projected ears with original vertices: inflated fan triangles
        // would otherwise fill authored notches that the zero-radius native path clips away.
        while polygon.count > 3 {
          var removed = false
          for index in polygon.indices {
            let a = polygon[(index + polygon.count - 1) % polygon.count]
            let b = polygon[index]
            let c = polygon[(index + 1) % polygon.count]
            let turn = cross(a, b, c) * sign
            if turn == 0 {
              polygon.remove(at: index)
              removed = true
              break
            }
            guard turn > 0 else { continue }
            let occupied = polygon.contains { other in
              other != a && other != b && other != c
                && cross(a, b, other) * sign >= 0
                && cross(b, c, other) * sign >= 0
                && cross(c, a, other) * sign >= 0
            }
            if !occupied {
              result.append([a, b, c])
              polygon.remove(at: index)
              removed = true
              break
            }
          }
          guard removed else { throw MissionNativeBridgeError.invalidGeometry }
        }
        result.append(polygon)
      }
      guard usableFaces > 0 else { throw MissionNativeBridgeError.invalidGeometry }
      return result
    }
    // Finite transformed vertex bounds conservatively reject meshes before any face work.
    // Nil means invalid bounds; false is a genuine bounded miss, not an invalid-face fallback.
    func intersectsBounds(_ vertices: [Vector3]) -> Bool? {
      guard vertices.allSatisfy(finite), let first = vertices.first else { return nil }
      var lower = first
      var upper = first
      for vertex in vertices.dropFirst() {
        lower = .init(min(lower.x, vertex.x), min(lower.y, vertex.y), min(lower.z, vertex.z))
        upper = .init(max(upper.x, vertex.x), max(upper.y, vertex.y), max(upper.z, vertex.z))
      }
      lower = lower - .init(radius, radius, radius)
      upper = upper + .init(radius, radius, radius)
      guard finite(lower), finite(upper) else { return nil }
      var entry = 0.0
      var exit = range
      for (start, motion, low, high) in [
        (origin.x, direction.x, lower.x, upper.x),
        (origin.y, direction.y, lower.y, upper.y),
        (origin.z, direction.z, lower.z, upper.z),
      ] {
        if motion == 0 {
          if start < low || start > high { return false }
        } else {
          let a = (low - start) / motion
          let b = (high - start) / motion
          entry = max(entry, min(a, b))
          exit = min(exit, max(a, b))
          if entry > exit { return false }
        }
      }
      return true
    }
    func swept(
      _ mesh: Mesh, transform: (Vector3) -> Vector3, target: GameplayHitTarget,
      body: SpaceBody? = nil, part: String? = nil, component: UUID? = nil
    ) -> Bool {
      let vertices = mesh.vertices.map(transform)
      guard let candidate = intersectsBounds(vertices) else { return false }
      guard candidate else { return true }
      guard let faces = try? prepare(mesh) else { return false }
      for face in faces {
        if let distance = ScriptSweptCollision.triangle(
          origin: origin, direction: direction, range: range, radius: radius,
          a: vertices[face[0]], b: vertices[face[1]], c: vertices[face[2]])
        {
          consider(distance, target: target, body: body, part: part, component: component)
        }
      }
      return true
    }
    var activeIDs: Set<Int> = []
    for body in bodies where body.energy > 0 {
      guard activeIDs.insert(body.id).inserted else {
        throw MissionNativeBridgeError.invalidGeometry
      }
    }
    let live = bodies.filter { $0.energy > 0 && !excludingBodyIDs.contains($0.id) }
    for body in live {
      let axes = [
        body.modelVector(.init(1, 0, 0)), body.modelVector(.init(0, 1, 0)),
        body.modelVector(.init(0, 0, 1)),
      ]
      guard finite(body.position), body.rotation.isFinite, body.orientation.validRotation,
        axes.allSatisfy(finite), axes.allSatisfy({ abs($0.dot($0) - 1) < 1e-6 }),
        abs(axes[0].dot(axes[1])) < 1e-6, abs(axes[0].dot(axes[2])) < 1e-6,
        abs(axes[1].dot(axes[2])) < 1e-6
      else { throw MissionNativeBridgeError.invalidGeometry }
    }
    // Native zero-radius rays retain the existing exact authored-polygon clipping path.
    if radius == 0 {
      let overrides = meshOverrides
      var native: [SpaceBody] = []
      for body in live where body.scriptNPC == nil && newtComponents[body.id] == nil {
        let mesh: Mesh
        if let override = overrides[body.id] {
          mesh = override
        } else {
          switch body.hull {
          case .station, .asteroid, .cargo, .missile:
            mesh = Mesh.hull(body.hull)
          default:
            guard let native = ShipCatalogue.nativeMesh(body.hull) else {
              throw MissionNativeBridgeError.invalidGeometry
            }
            mesh = native
          }
        }
        guard
          let candidate = intersectsBounds(
            mesh.vertices.map { body.position + body.modelVector($0) })
        else { throw MissionNativeBridgeError.invalidGeometry }
        if candidate {
          _ = try prepare(mesh)
          native.append(body)
        }
      }
      var playerMesh: Mesh?
      if includePlayer {
        let mesh = self.playerMesh
        guard let candidate = intersectsBounds(mesh.vertices) else {
          throw MissionNativeBridgeError.invalidGeometry
        }
        if candidate {
          _ = try prepare(mesh)
          playerMesh = mesh
        }
      }
      if let hit = GameplayRaycast.nearest(
        origin: origin, direction: nativeDirection, maxDistance: range,
        bodies: native, playerMesh: playerMesh, meshOverrides: overrides)
      {
        let body: SpaceBody?
        if case .body(let id) = hit.target {
          body = native.first { $0.id == id }
        } else {
          body = nil
        }
        consider(hit.distance, target: hit.target, body: body, nativePoint: hit.point)
      }
    }
    for body in live {
      guard finite(body.position), body.orientation.validRotation,
        body.rotation.isFinite
      else { throw MissionNativeBridgeError.invalidGeometry }
      if let components = newtComponents[body.id] {
        for local in components {
          if radius == 0 {
            guard let candidate = intersectsBounds(
              local.vertices.map { body.position + body.modelVector($0) })
            else { throw MissionNativeBridgeError.invalidGeometry }
            guard candidate else { continue }
            _ = try prepare(local)
            if let hit = GameplayRaycast.nearest(
              origin: origin, direction: nativeDirection, maxDistance: range,
              bodies: [body], meshOverrides: [body.id: local])
            {
              // Native components retain the body's existing damage/custody identity.
              consider(hit.distance, target: hit.target, body: body, nativePoint: hit.point)
            }
          } else {
            guard swept(local, transform: { body.position + body.modelVector($0) },
              target: .body(body.id), body: body)
            else { throw MissionNativeBridgeError.invalidGeometry }
          }
        }
      } else if let npc = body.scriptNPC {
        guard npc.valid, let models = customModels[body.id], models.valid, let root = models.root
        else { throw MissionNativeBridgeError.invalidGeometry }
        func custom(
          _ mesh: Mesh, position: Vector3, orientation: Basis3, scale: Double,
          part: String? = nil, component: UUID? = nil
        ) -> Bool {
          guard finite(position), orientation.validRotation, scale.isFinite, scale > 0,
            npc.fit.definition.scale.isFinite, npc.fit.definition.scale > 0
          else { return false }
          let local = Mesh(
            vertices: mesh.vertices.map {
              (position + orientation.apply($0 * scale)) * npc.fit.definition.scale
            }, faces: mesh.faces, preserveWinding: true)
          if radius == 0 {
            guard
              let candidate = intersectsBounds(
                local.vertices.map { body.position + body.modelVector($0) })
            else { return false }
            guard candidate else { return true }
            guard (try? prepare(local)) != nil else { return false }
            if let hit = GameplayRaycast.nearest(
              origin: origin, direction: nativeDirection,
              maxDistance: range, bodies: [body], meshOverrides: [body.id: local])
            {
              consider(
                hit.distance, target: hit.target, body: body, part: part, component: component,
                nativePoint: hit.point)
            }
            return true
          }
          return swept(
            local, transform: { body.position + body.modelVector($0) },
            target: .body(body.id), body: body, part: part, component: component)
        }
        guard custom(root, position: .init(0, 0, 0), orientation: .init(), scale: 1) else {
          throw MissionNativeBridgeError.invalidGeometry
        }
        for spec in npc.fit.definition.components ?? [] where spec.solid {
          guard let state = npc.components[spec.id], state.energy > 0 else { continue }
          guard let mesh = models.components[spec.id],
            custom(
              mesh, position: spec.position, orientation: spec.orientation, scale: spec.scale,
              part: spec.id, component: state.identity)
          else { throw MissionNativeBridgeError.invalidGeometry }
        }
      } else if radius > 0 {
        guard let mesh = sweptMeshes[body.id],
          swept(
            mesh, transform: { body.position + body.modelVector($0) },
            target: .body(body.id), body: body)
        else { throw MissionNativeBridgeError.invalidGeometry }
      }
    }
    if radius > 0, includePlayer {
      guard swept(playerMesh, transform: { $0 }, target: .player) else {
        throw MissionNativeBridgeError.invalidGeometry
      }
    }
    for celestial in celestials {
      let inflated = celestial.radius + radius
      guard finite(celestial.position), celestial.radius.isFinite, celestial.radius > 0,
        inflated.isFinite, inflated > 0
      else {
        throw MissionNativeBridgeError.invalidGeometry
      }
      if let distance = ScriptSweptCollision.sphere(
        origin: origin - celestial.position,
        direction: direction, radius: inflated)
      {
        consider(distance, target: .celestial(celestial.kind))
      }
    }
    return nearest
  }
}

/// A genuine selected geometry query, never an emission or damage capability.
final class SelectedNPCBeamPlan: Sendable {
  let geometry: MissionCollisionQueryGeometry
  let owner: ActorIdentity
  let bodyID: Int
  let launch: Vector3
  let openingSource: SpaceBody
  let decision: LegacyNPCFlightDecision

  fileprivate init(geometry: MissionCollisionQueryGeometry, owner: ActorIdentity,
    bodyID: Int, launch: Vector3, source: SpaceBody,
    decision: LegacyNPCFlightDecision) {
    self.geometry = geometry; self.owner = owner; self.bodyID = bodyID; self.launch = launch
    openingSource = source; self.decision = decision
  }
}

extension Game {
  /// Select the original pursuit/muzzle/range geometry while the actual source
  /// still occupies its real opening scene. Cadence and all effects remain live.
  @inline(never)
  func prepareSelectedLegacyNPCBeam(entry: CurrentNewtNPCMotion,
    geometry: MissionCollisionQueryGeometry) -> SelectedNPCBeamPlan?
  {
    guard geometry.matchesOpening(flight: storedFlightSimulation(), bodies: bodies,
      epoch: nativeStationRuntimeEpoch), geometry.hasSelectedPath,
      let decision = entry.legacy, decision.duration.isFinite, decision.duration > 0,
      decision.physicalTime == storedFlightSimulation().physicalTime,
      decision.duration == geometry.selectedDuration,
      decision.epoch == nativeStationRuntimeEpoch, decision.bodyID == entry.bodyID,
      let source = bodies.first(where: { $0.id == entry.bodyID && $0.energy > 0 }),
      bodies.filter({ $0.id == entry.bodyID }).count == 1,
      let owner = source.physical?.identity, owner == entry.actor, decision.actor == owner,
      !isEMPDisabled(source), source.physical?.empCrewPod == nil,
      source.rotation == entry.modelPhase, source.rotationRate == entry.modelPhaseRate,
      let selected = geometry.selectedBody(id: source.id), decision.start == selected.position
    else { return nil }
    let expected: Vector3
    switch decision.driver {
    case .ordinaryPlayerEngagement:
      guard let player = storedFlightSimulation().player,
        owner.system == player.system, owner.visit == player.visit,
        owner.entity >= 2, owner.entity < storedFlightSimulation().nextActor,
        source.blackjackRole == nil, source.physical?.npc?.intention == .engage(player),
        decision.intention == source.physical?.npc?.intention
      else { return nil }
      expected = LegacyNPCFlightDecision.ordinaryPosition(selected.position,
        maximumSpeed: source.nativeNavalCombat?.speed, delta: decision.duration)
      guard expected.length < 1500 else { return nil }
    case .blackjack:
      guard source.blackjackRole != nil, source.blackjackIdentity == decision.blackjackIdentity,
        selected.position.length < 1500,
        max(0, (source.blackjackLaserCooldown ?? 0) - decision.duration) == 0
      else { return nil }
      expected = LegacyNPCFlightDecision.blackjackPosition(selected.position, delta: decision.duration)
    }
    guard expected == decision.end, expected.finite, expected.length > 0,
      geometry.selectedFrame.systemPoint(selected.position) == decision.worldStart,
      geometry.selectedFrame.systemPoint(expected) == decision.worldEnd
    else { return nil }
    return .init(geometry: geometry, owner: owner, bodyID: source.id,
      launch: decision.worldEnd, source: source, decision: decision)
  }
}


/// A native ray produced at the actual retained source turn from an opening
/// selection plan and current, evidence-joined live/component availability.
private final class SelectedLegacyBeamLiveSource: Sendable {
  let body: SpaceBody
  init(_ body: SpaceBody) { self.body = body }
}

final class SelectedNPCBeamQuery: Sendable {
  let plan: SelectedNPCBeamPlan
  let geometry: MissionCollisionQueryGeometry
  let launch: Vector3
  let contact: MissionCollisionContact?
  var owner: ActorIdentity { plan.owner }
  var bodyID: Int { plan.bodyID }
  fileprivate init(plan: SelectedNPCBeamPlan, geometry: MissionCollisionQueryGeometry,
    launch: Vector3, contact: MissionCollisionContact?) {
    self.plan = plan; self.geometry = geometry; self.launch = launch; self.contact = contact
  }
}

extension Game {
  @inline(never)
  func querySelectedLegacyNPCBeam(_ plan: SelectedNPCBeamPlan,
    evidence: CurrentNewtNativeClockEvidence, admittedAtEnd: CurrentNewtEndBirths? = nil)
    -> SelectedNPCBeamQuery?
  {
    guard evidence.validatesSelectedBeamGeometry(plan.geometry, closing: self,
      admittedAtEnd: admittedAtEnd) else { return nil }
    return querySelectedLegacyBeamAfterValidation(plan, evidence: evidence, admittedAtEnd: admittedAtEnd)
  }

  @inline(never)
  private func selectedLegacyBeamLiveSource(_ plan: SelectedNPCBeamPlan) -> SelectedLegacyBeamLiveSource? {
    guard let source = bodies.first(where: { $0.id == plan.bodyID && $0.physical?.identity == plan.owner }),
      source.energy > 0, !isEMPDisabled(source), source.physical?.empCrewPod == nil,
      source.physical?.npc?.intention == plan.openingSource.physical?.npc?.intention,
      source.blackjackIdentity == plan.openingSource.blackjackIdentity
    else { return nil }
    return .init(source)
  }

  @inline(never)
  private func querySelectedLegacyBeamAfterValidation(_ plan: SelectedNPCBeamPlan,
    evidence: CurrentNewtNativeClockEvidence, admittedAtEnd: CurrentNewtEndBirths?) -> SelectedNPCBeamQuery?
  {
    guard let source = selectedLegacyBeamLiveSource(plan) else { return nil }
    return querySelectedLegacyBeamPoses(plan, source: source, evidence: evidence, admittedAtEnd: admittedAtEnd)
  }

  @inline(never)
  private func querySelectedLegacyBeamPoses(_ plan: SelectedNPCBeamPlan, source: SelectedLegacyBeamLiveSource,
    evidence: CurrentNewtNativeClockEvidence, admittedAtEnd: CurrentNewtEndBirths?) -> SelectedNPCBeamQuery?
  {
    guard let poses = evidence.selectedLegacyBeamModelPoses(geometry: plan.geometry,
        source: plan.owner, current: self, admittedAtEnd: admittedAtEnd),
      let sourcePose = poses[plan.owner] else { return nil }
    return querySelectedLegacyBeamComponents(plan, source: source, poses: poses, sourcePose: sourcePose,
      evidence: evidence, admittedAtEnd: admittedAtEnd)
  }

  @inline(never)
  private func querySelectedLegacyBeamComponents(_ plan: SelectedNPCBeamPlan, source: SelectedLegacyBeamLiveSource,
    poses: [ActorIdentity: ShipPose], sourcePose: ShipPose, evidence: CurrentNewtNativeClockEvidence,
    admittedAtEnd: CurrentNewtEndBirths?) -> SelectedNPCBeamQuery?
  {
    guard let parts = evidence.selectedLegacyBeamComponents(geometry: plan.geometry,
        source: plan.owner, current: self, admittedAtEnd: admittedAtEnd) else { return nil }
    return querySelectedLegacyBeamGeometry(plan, source: source, poses: poses, sourcePose: sourcePose, parts: parts)
  }

  @inline(never)
  private func querySelectedLegacyBeamGeometry(_ plan: SelectedNPCBeamPlan, source: SelectedLegacyBeamLiveSource,
    poses: [ActorIdentity: ShipPose], sourcePose: ShipPose,
    parts: [ActorIdentity: [CurrentNewtKitComponent]]) -> SelectedNPCBeamQuery?
  {
    do {
      let live = try captureMissionCollisionGeometry(path: nil)
      let selected = try plan.geometry.currentScene(live: live, poses: poses, components: parts, source: plan.owner)
      let launch: Vector3
      if source.body.isAegisPrototype, let muzzle = AegisPrototype.muzzle {
        launch = sourcePose.systemPoint(muzzle)
      } else { launch = sourcePose.position }
      let emitter = selected.selectedFrame.shipPoint(launch)
      let direction = selected.playerSurfaceAim(from: emitter) - emitter
      guard direction.finite, direction.length.isFinite, direction.length > 0 else { return nil }
      let contact = try selected.query(from: emitter, direction: direction.unit,
        range: direction.length + 1, radius: 0, excludingBodyIDs: [plan.bodyID], includePlayer: true,
        emitter: plan.owner, launch: launch)
      return .init(plan: plan, geometry: selected, launch: launch, contact: contact)
    } catch { return nil }
  }
}

extension Game {
  /// Only actual retained motion evidence can rejoin a selected historical ray
  /// to current target health and the same installed mission component.
  @inline(never)
  func bindSelectedNativeMissionContact(_ contact: MissionCollisionContact,
    owner: ActorIdentity, evidence: CurrentNewtNativeClockEvidence,
    admittedAtEnd: CurrentNewtEndBirths? = nil) throws -> MissionCollisionContact
  {
    guard let geometry = contact.selectedGeometry, contact.selectedEmitter == owner,
      contact.selectedLaunch?.finite == true,
      evidence.validatesSelectedBeamGeometry(geometry, closing: self, admittedAtEnd: admittedAtEnd)
    else { throw MissionNativeBridgeError.sourceMismatch }
    return try bindSelectedNativeMissionContactAfterValidation(contact, owner: owner, geometry: geometry)
  }

  @inline(never)
  private func bindSelectedNativeMissionContactAfterValidation(
    _ contact: MissionCollisionContact, owner: ActorIdentity, geometry: MissionCollisionQueryGeometry
  ) throws -> MissionCollisionContact {
    guard let source = bodies.first(where: { $0.physical?.identity == owner }),
      source.energy > 0, !isEMPDisabled(source),
      let old = contact.selectedTargetBody, let actor = old.physical?.identity,
      let target = bodies.first(where: { $0.id == old.id && $0.physical?.identity == actor }),
      bodies.filter({ $0.id == old.id }).count == 1, target.energy > 0,
      target.hull == old.hull, target.missionActorID == old.missionActorID,
      target.missionInstanceID == old.missionInstanceID,
      target.physical?.catalogueShipID == old.physical?.catalogueShipID,
      target.physical?.spawnIdentity == old.physical?.spawnIdentity,
      target.scriptNPC?.fit == old.scriptNPC?.fit, target.scriptNPC != nil
    else { throw MissionNativeBridgeError.sourceMismatch }
    if let part = contact.victimPart {
      guard let component = contact.componentUUID,
        let state = target.scriptNPC?.components[part], state.identity == component, state.energy > 0
      else { throw MissionNativeBridgeError.sourceMismatch }
    } else if contact.componentUUID != nil { throw MissionNativeBridgeError.sourceMismatch }
    return .init(hit: contact.hit, victimPart: contact.victimPart, componentUUID: contact.componentUUID,
      body: target, selection: geometry, emitter: owner, launch: contact.selectedLaunch)
  }
}


extension Game {
  /// Bind only an actual source-qualified continuous native observation. This
  /// does not turn a static ray or decoded contact into a moving-target proof.
  @inline(never)
  func bindNativeOrdnanceCurveContact(_ observation: CurrentNewtOrdnanceCurveContact) throws
    -> MissionCollisionContact {
    let scene = observation.scene
    let interval = scene.motion.opening.interval
    let native = observation.native
    guard let frame = scene.ordnanceFrame,
      frame.entries.contains(where: { $0 === observation.opening }),
      nativeStationRuntimeEpoch == observation.opening.epoch,
      storedFlightSimulation().system == frame.context.system,
      storedFlightSimulation().visit == frame.context.visit,
      storedFlightSimulation().physicalTime == observation.upperPhysicalTime,
      native.lowerTime >= 0, native.upperTime >= native.lowerTime,
      native.upperTime <= interval.end - interval.start, native.radius == 0,
      native.centre.finite, native.matches(observation.target.hull)
    else { throw NativeMissionImpactError.staleProof }
    let position = try nativeCurveProjectilePosition(observation, start: interval.start)
    guard let actor = observation.target.actor else { throw NativeMissionImpactError.staleProof }
    return try bindNativeCurveActor(observation, actor: actor, projectilePosition: position)
  }

  @inline(never)
  private func nativeCurveProjectilePosition(
    _ observation: CurrentNewtOrdnanceCurveContact, start: Double
  ) throws -> Vector3 {
    try bodies.withUnsafeBufferPointer { stored in
      for index in stored.indices {
        let projectile = stored.baseAddress!.advanced(by: index)
        if Self.nativeCurveBodyHasID(projectile.pointee, id: observation.opening.body.id) {
          return try nativeCurveProjectilePosition(projectile.pointee, observation: observation, start: start)
        }
      }
      throw NativeMissionImpactError.staleProof
    }
  }

  @inline(never)
  private static func nativeCurveBodyHasID(_ body: borrowing SpaceBody, id: Int) -> Bool {
    body.id == id
  }

  @inline(never)
  private func nativeCurveProjectilePosition(
    _ projectile: borrowing SpaceBody, observation: CurrentNewtOrdnanceCurveContact, start: Double
  ) throws -> Vector3 {
    guard projectile.energy > 0, projectile.nativeGeometryIdentity() == observation.opening.actor,
      let state = projectile.physical?.ordnance,
      projectile.physical?.attackOrigin == state.origin,
      observation.opening.matchesCurrentState(state, at: start)
    else { throw NativeMissionImpactError.staleProof }
    return state.position
  }

  @inline(never)
  private static func nativeCurveSamePose(_ left: ShipPose, _ right: ShipPose) -> Bool {
    (left.position - right.position).length < 1e-7
      && (left.orientation.x - right.orientation.x).length < 1e-7
      && (left.orientation.y - right.orientation.y).length < 1e-7
      && (left.orientation.z - right.orientation.z).length < 1e-7
  }

  @inline(never)
  private func bindNativeCurveActor(
    _ observation: CurrentNewtOrdnanceCurveContact, actor: ActorIdentity, projectilePosition: Vector3
  ) throws -> MissionCollisionContact {
    if actor == storedFlightSimulation().player {
      guard energy > 0, Self.nativeCurveSamePose(storedFlightSimulation().pose, observation.native.targetPose),
        observation.target.component == "player"
      else { throw NativeMissionImpactError.staleProof }
      return try finishNativeCurveContact(observation, hit: .player, target: nil, projectilePosition: projectilePosition)
    }
    return try bindNativeCurveBody(observation, actor: actor, projectilePosition: projectilePosition)
  }

  @inline(never)
  private func bindNativeCurveBody(
    _ observation: CurrentNewtOrdnanceCurveContact, actor: ActorIdentity, projectilePosition: Vector3
  ) throws -> MissionCollisionContact {
    try bodies.withUnsafeBufferPointer { stored in
      for index in stored.indices {
        let body = stored.baseAddress!.advanced(by: index)
        if body.pointee.nativeGeometryIdentity() == actor {
          guard body.pointee.energy > 0 else { throw NativeMissionImpactError.staleProof }
          try requireNativeCurveOpeningBody(body.pointee, observation: observation, actor: actor)
          try requireNativeCurveBodyGeometry(body.pointee, observation: observation)
          try requireNativeCurveInstalledPart(body.pointee, observation: observation)
          // Only a completely validated actual target becomes the owned contact.
          let selected = body.pointee
          return try finishNativeCurveContact(observation, hit: .body(selected.id), target: selected,
            projectilePosition: projectilePosition)
        }
      }
      throw NativeMissionImpactError.staleProof
    }
  }

  @inline(never)
  private func requireNativeCurveOpeningBody(
    _ body: borrowing SpaceBody, observation: CurrentNewtOrdnanceCurveContact, actor: ActorIdentity
  ) throws {
    try withUnsafePointer(to: body) { current in
      try observation.scene.motion.opening.before.bodies.withUnsafeBufferPointer { stored in
        for index in stored.indices {
          let original = stored.baseAddress!.advanced(by: index)
          if original.pointee.nativeGeometryIdentity() == actor {
            try Self.requireNativeCurveBodyIdentity(current.pointee, original: original.pointee)
            return
          }
        }
        throw NativeMissionImpactError.staleProof
      }
    }
  }

  @inline(never)
  private static func requireNativeCurveBodyIdentity(
    _ body: borrowing SpaceBody, original: borrowing SpaceBody
  ) throws {
    guard body.id == original.id, body.hull == original.hull,
      body.missionActorID == original.missionActorID,
      body.missionInstanceID == original.missionInstanceID,
      body.nativeGeometryCatalogueID() == original.nativeGeometryCatalogueID(),
      body.physical?.spawnIdentity == original.physical?.spawnIdentity,
      body.scriptNPC?.fit == original.scriptNPC?.fit
    else { throw NativeMissionImpactError.staleProof }
  }

  @inline(never)
  private func requireNativeCurveBodyGeometry(
    _ body: borrowing SpaceBody, observation: CurrentNewtOrdnanceCurveContact
  ) throws {
    let claimed: Bool
    if body.nativeGeometryStock() != nil { claimed = true }
    else { claimed = body.nativeGeometryReceipt() != nil }
    if claimed {
      guard let parts = try currentNewtGeometryComponents(for: body),
        let part = parts.first(where: { $0.id == observation.target.component }),
        let mesh = part.collisionMesh, mesh.vertices == observation.target.mesh.vertices,
        mesh.faces == observation.target.mesh.faces, Self.nativeCurveSamePose(part.pose, observation.native.targetPose)
      else { throw NativeMissionImpactError.staleProof }
    } else {
      guard Self.nativeCurveSamePose(modelPose(of: body), observation.native.targetPose)
      else { throw NativeMissionImpactError.staleProof }
    }
  }

  @inline(never)
  private func requireNativeCurveInstalledPart(
    _ body: borrowing SpaceBody, observation: CurrentNewtOrdnanceCurveContact
  ) throws {
    if let part = observation.target.victimPart {
      guard let component = observation.target.componentUUID,
        let installed = body.scriptNPC?.components[part], installed.identity == component,
        installed.energy > 0
      else { throw NativeMissionImpactError.staleProof }
    } else if observation.target.componentUUID != nil { throw NativeMissionImpactError.staleProof }
  }

  @inline(never)
  private func finishNativeCurveContact(
    _ observation: CurrentNewtOrdnanceCurveContact, hit: GameplayHitTarget, target: SpaceBody?,
    projectilePosition: Vector3
  ) throws -> MissionCollisionContact {
    let point = storedFlightSimulation().pose.shipPoint(observation.native.centre)
    let distance = (observation.native.centre - projectilePosition).length
    guard point.finite, distance.isFinite else { throw NativeMissionImpactError.staleProof }
    return .init(hit: .init(target: hit, distance: distance, point: point),
      victimPart: observation.target.victimPart, componentUUID: observation.target.componentUUID,
      body: target, curve: observation)
  }
}
