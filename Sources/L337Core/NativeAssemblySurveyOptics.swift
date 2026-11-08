import Foundation

enum NativeAssemblySurveyOpticalRules {
  static let requiredSeconds = 12.0
  static let maximumAimDegrees = 2.0
  static let surfaceRange = 250.0...1500.0
  /// Sampling policy estimate, matching the existing native observer's maximum bracket.
  /// Endpoint samples are not a continuous geometric or consent proof between frames.
  static let maximumInterval = 0.1
}

/// Read-only reason from the actual acquisition path, never a register reading or saved fact.
/// Only this file constructs a report; positive samples still use their private constructor.
struct NativeAssemblyOpticalAcquisitionReport: Sendable {
  let sample: NativeAssemblyOpticalSample?
  let refusal: String?

  private init(sample: NativeAssemblyOpticalSample?, refusal: String?) {
    self.sample = sample
    self.refusal = refusal
  }

  fileprivate static func acquired(_ sample: NativeAssemblyOpticalSample) -> Self {
    .init(sample: sample, refusal: nil)
  }

  fileprivate static func unavailable(_ reason: String) -> Self {
    .init(sample: nil, refusal: String(reason.prefix(1024)))
  }
}

/// Actual optical instrument data only. No original-register identity, consent, occupancy,
/// source signature, survey reading or mission receipt can be decoded or inferred from it.
final class NativeAssemblyOpticalSample: Sendable {
  let mission: UUID
  let caseRevision: UInt64
  let reference: NativeAssemblyReferenceBinding
  let targeting: OwnedEquipmentItem
  let player: ActorIdentity
  let actor: ActorIdentity
  let component: UUID?
  let part: String?
  let frame: UInt64
  let physicalTime: Double
  let epoch: UUID
  let targetPose: ShipPose
  let observerPose: ShipPose
  let surfaceRange: Double
  let surfacePoint: Vector3
  let aimDegrees: Double
  private let vertices: [Vector3]
  private let faces: [[Int]]
  private let models: [String: String]

  private init(game: borrowing Game, instance: ScriptInstance,
    reference: NativeAssemblyReferenceBinding, targeting: OwnedEquipmentItem,
    player: ActorIdentity, actor: ActorIdentity, body: SpaceBody,
    contact: MissionCollisionContact, aimDegrees: Double)
  {
    mission = instance.id
    caseRevision = instance.revision
    self.reference = reference
    self.targeting = targeting
    self.player = player
    self.actor = actor
    component = contact.componentUUID
    part = contact.victimPart
    frame = game.gameplayRevision
    physicalTime = game.commander.flightSimulation.physicalTime
    epoch = game.nativeStationRuntimeEpoch
    targetPose = game.modelPose(of: body)
    observerPose = game.commander.flightSimulation.pose
    surfaceRange = contact.hit.distance
    surfacePoint = observerPose.systemPoint(contact.hit.point)
    self.aimDegrees = aimDegrees
    let mesh = game.gameplayMesh(for: body)
    vertices = mesh.vertices
    faces = mesh.faces
    models = body.scriptNPC?.fit.models ?? [:]
  }

  /// Stable instrument and physical target joins; moving poses belong to the new sample.
  func sameProbe(as other: NativeAssemblyOpticalSample) -> Bool {
    mission == other.mission && caseRevision == other.caseRevision
      && reference == other.reference && targeting == other.targeting
      && player == other.player && actor == other.actor
      && component == other.component && part == other.part && epoch == other.epoch
      && vertices == other.vertices && faces == other.faces && models == other.models
  }

  /// Matching clocks alone cannot bridge a changed camera/target pose between acquisitions.
  func sameObservation(as other: NativeAssemblyOpticalSample) -> Bool {
    sameProbe(as: other) && frame == other.frame && physicalTime == other.physicalTime
      && targetPose == other.targetPose && observerPose == other.observerPose
      && surfaceRange == other.surfaceRange && surfacePoint == other.surfacePoint
      && aimDegrees == other.aimDegrees
  }

  /// All opaque bodies/celestials compete in the existing zero-radius native mesh query.
  /// A real unrelated ship/station can calibrate this instrument, never stand in for Darik's
  /// three original registers. The absent original-source/consent join is deliberately separate.
  @inline(never)
  static func acquire(in game: borrowing Game) throws -> NativeAssemblyOpticalSample? {
    try acquisitionReport(in: game).sample
  }

  /// Same ordered predicates and ray as acquire; refusal text creates no permission.
  @inline(never)
  static func acquisitionReport(in game: borrowing Game) throws -> NativeAssemblyOpticalAcquisitionReport {
    guard !game.isMissionTrial else { return .unavailable("context.missionTrial") }
    guard game.trialTitle == nil else { return .unavailable("context.trialTitle") }
    guard !game.docked else { return .unavailable("context.docked") }
    guard !game.paused else { return .unavailable("context.paused") }
    guard game.screen == .front else { return .unavailable("context.screen: \(game.screen)") }
    guard !game.playerEMPDisabled else { return .unavailable("context.empDisabled") }
    guard game.energy.isFinite else { return .unavailable("context.nonfiniteEnergy") }
    guard game.energy > 0 else { return .unavailable("context.energy: \(game.energy)") }
    guard game.jumpCountdown == nil else { return .unavailable("context.jumpCountdown") }
    guard game.pendingNativeStationDock == nil else { return .unavailable("context.pendingDock") }
    guard game.gameplayRevision > 0 else { return .unavailable("context.frame: \(game.gameplayRevision)") }
    guard game.commander.flightSimulation.valid else { return .unavailable("context.invalidFlightState") }
    guard game.commander.equipmentStateValid else { return .unavailable("context.invalidEquipmentState") }
    guard let instance = game.assemblyOfOrbitsMission else { return .unavailable("case.missing") }
    guard game.assemblyOfOrbitsPack?.digest == instance.digest else { return .unavailable("case.packDigest") }
    guard NativeAssemblyOfOrbitsSave.validateClaims(game.commander) else { return .unavailable("case.invalidClaims: revision=\(instance.revision),outcome=\(instance.outcome)") }
    guard let reference = try? NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: game.commander) else { return .unavailable("reference.unresolvedCustody") }
    guard let inventory = game.commander.equipmentInventory else { return .unavailable("equipment.missingInventory") }
    guard let targeting = game.commander.fittedEquipment(at: .targetingCore) else { return .unavailable("equipment.missingTargeting") }
    guard inventory.items.filter({ $0.id == targeting.id }) == [targeting] else { return .unavailable("equipment.targetingMultiplicity") }
    guard targeting.location == .init(hullInstanceID: inventory.activeHull, slot: .targetingCore) else { return .unavailable("equipment.targetingLocation") }
    guard TargetingTier.from(targeting.node.key) != nil else { return .unavailable("equipment.unknownTargetingTier") }
    guard game.commander.fittedComponent(at: .targetingCore) == targeting.component else { return .unavailable("equipment.targetingComponent") }
    guard reference.owner == inventory.owner else { return .unavailable("reference.owner") }
    guard reference.carrier == inventory.activeHull else { return .unavailable("reference.carrier") }
    guard reference.inventoryRevision == inventory.revision else { return .unavailable("reference.inventoryRevision: reference=\(reference.inventoryRevision),actual=\(inventory.revision)") }
    guard let body = game.informationTargetBody else { return .unavailable("target.missing") }
    guard body.energy.isFinite else { return .unavailable("target.nonfiniteEnergy") }
    guard body.energy > 0 else { return .unavailable("target.energy: \(body.energy)") }
    guard body.position.finite else { return .unavailable("target.nonfinitePosition: \(body.position)") }
    guard body.position.length.isFinite else { return .unavailable("target.nonfiniteRange") }
    guard body.position.z > 0 else { return .unavailable("target.behind: \(body.position)") }
    guard body.scriptShot == nil else { return .unavailable("target.scriptShot") }
    guard game.bodies.filter({ $0.id == body.id }).count == 1 else { return .unavailable("target.duplicateBodyID: \(body.id)") }
    guard let physical = body.physical else { return .unavailable("target.missingPhysical") }
    guard physical.identity.entity > 0 else { return .unavailable("target.invalidEntity: \(physical.identity)") }
    guard let player = game.commander.flightSimulation.player else { return .unavailable("player.missing") }
    guard player.entity == 0 else { return .unavailable("player.invalidEntity: \(player)") }
    guard physical.identity.system == player.system else { return .unavailable("target.playerSystem") }
    guard physical.identity.visit == player.visit else { return .unavailable("target.playerVisit") }
    guard let context = game.gameplayContext() else { return .unavailable("context.missingGameplay") }
    guard context.player.identity == player else { return .unavailable("context.playerIdentity") }
    guard context.system == game.systemIdentity else { return .unavailable("context.system") }
    guard context.visit == player.visit else { return .unavailable("context.visit") }
    guard context.physicalTime == game.commander.flightSimulation.physicalTime else { return .unavailable("context.physicalTime") }
    guard context.actors.filter({ $0.identity == physical.identity }).count == 1 else { return .unavailable("target.contextMultiplicity: \(physical.identity)") }
    guard game.bodies.filter({ $0.physical?.identity == physical.identity }).count == 1 else { return .unavailable("target.physicalMultiplicity: \(physical.identity)") }
    let aim = atan2(hypot(body.position.x, body.position.y), body.position.z) * 180 / Double.pi
    let pose = game.modelPose(of: body)
    guard aim.isFinite else { return .unavailable("optics.nonfiniteAim: \(aim)") }
    guard aim <= NativeAssemblySurveyOpticalRules.maximumAimDegrees else { return .unavailable("optics.aimExceeded: actual=\(aim),maximum=\(NativeAssemblySurveyOpticalRules.maximumAimDegrees),target=\(body.position)") }
    guard pose.position.finite else { return .unavailable("optics.nonfinitePosePosition: \(pose.position)") }
    guard pose.orientation.validRotation else { return .unavailable("optics.invalidPoseRotation: x=\(pose.orientation.x),y=\(pose.orientation.y),z=\(pose.orientation.z)") }
    guard let contact = try game.nearestMissionCollision(from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: NativeAssemblySurveyOpticalRules.surfaceRange.upperBound, radius: 0, includePlayer: false) else { return .unavailable("optics.noRayContact: maximum=\(NativeAssemblySurveyOpticalRules.surfaceRange.upperBound)") }
    guard contact.hit.target == .body(body.id) else { return .unavailable("optics.otherRayTarget: actual=\(contact.hit.target),expectedBody=\(body.id),distance=\(contact.hit.distance),point=\(contact.hit.point),part=\(String(describing: contact.victimPart)),component=\(String(describing: contact.componentUUID))") }
    guard contact.hit.point.finite else { return .unavailable("optics.nonfiniteRayPoint: \(contact.hit.point)") }
    guard NativeAssemblySurveyOpticalRules.surfaceRange.contains(contact.hit.distance) else { return .unavailable("optics.surfaceRange: actual=\(contact.hit.distance),minimum=\(NativeAssemblySurveyOpticalRules.surfaceRange.lowerBound),maximum=\(NativeAssemblySurveyOpticalRules.surfaceRange.upperBound)") }
    return .acquired(.init(game: game, instance: instance, reference: reference, targeting: targeting,
      player: player, actor: physical.identity, body: body, contact: contact, aimDegrees: aim))
  }
}

extension Game {
  func assemblySurveyOpticalSample() throws -> NativeAssemblyOpticalSample? {
    try NativeAssemblyOpticalSample.acquire(in: self)
  }

  func assemblySurveyOpticalAcquisitionReport() throws -> NativeAssemblyOpticalAcquisitionReport {
    try NativeAssemblyOpticalSample.acquisitionReport(in: self)
  }
}
