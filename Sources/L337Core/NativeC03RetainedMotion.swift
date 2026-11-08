import Foundation

/// Unwired structural projections only. No capture, decoded body or receipt matcher issues
/// a C03 original, allocates a native actor, proves life, or installs a source/admission hook.
enum NativeC03RetainedMotion {
  enum Failure: Error { case invalidFrame, invalidOriginal, invalidCondition, terminalOriginal }
  /// Diagnostic structural result, never source/admission authority. Receipt checks occur only
  /// after all supplied projection/condition facts have matched, so refusal is testable.
  enum AdmissionComparison: Equatable, Sendable {
    case inconsistentFacts, foreignReceipt, matchingFacts
  }

  /// Temporary admission input, never a second Codable motion/condition owner.
  /// `historicalPhysical` retains an OLD address. Only the native allocator may supply a new one.
  struct AdmissionProjection: Sendable {
    let original: NativeHollowManifestOriginalSealBinding
    let logicalActor: UUID
    let alias: String
    let reference: ShipPose
    let body: SpaceBody
    let historicalPhysical: PhysicalActorState
    let worldRootPose: ShipPose
  }

  /// The caller supplies its actual post-flight, velocity-synchronized body and frozen first
  /// source frame. The returned body is condition data for the existing owned actor only.
  static func capture(
    body: SpaceBody, owned: ScriptOwnedActor,
    original: NativeHollowManifestOriginalSealBinding,
    flight: FlightSimulationState, reference: ShipPose
  ) throws -> SpaceBody {
    try validateFrame(flight, reference: reference)
    try validateOriginal(body: body, owned: owned, original: original)
    guard let physical = body.physical, original.actor.system == flight.system,
      original.actor.visit == flight.visit, original.actor.entity < flight.nextActor,
      let spawn = physical.spawnIdentity, spawn.sequence < flight.nextSpawn,
      flight.physicalTime >= original.issuedTime, let npc = body.scriptNPC,
      same(flight.pose.orientation.apply(npc.velocity), physical.velocity)
    else { throw Failure.invalidCondition }
    var retained = body
    retained.position = reference.shipPoint(flight.pose.systemPoint(body.position))
    retained.orientation = body.orientation.transformed(by: flight.pose.orientation)
      .relative(to: reference.orientation)
    retained.scriptNPC?.velocity = reference.shipVector(physical.velocity)
    // Physical velocity/omega already use inertial axes. Model rotation is a separate phase.
    guard validBody(retained), let retainedNPC = retained.scriptNPC,
      same(rawPose(retained, in: reference), rawPose(body, in: flight.pose)),
      same(
        Game.modelPose(of: retained, player: reference),
        Game.modelPose(of: body, player: flight.pose)),
      same(reference.orientation.apply(retainedNPC.velocity), physical.velocity)
    else { throw Failure.invalidCondition }
    return retained
  }

  /// Convert the same last observed inertial pose to the current native admission frame.
  /// No time integration, route position, new actor identity or default angular state is used.
  static func projectForAdmission(
    owned: ScriptOwnedActor, original: NativeHollowManifestOriginalSealBinding,
    reference: ShipPose, flight: FlightSimulationState, station: SpaceBody
  ) throws -> AdmissionProjection {
    try validateFrame(flight, reference: reference)
    try validateStation(station, flight: flight)
    try validateOriginal(body: owned.body, owned: owned, original: original)
    let retained = owned.body
    guard retained.energy > 0, owned.presence != .destroyed,
      retained.physical?.deathIncidentID == nil, retained.physical?.deathOrigin == nil
    else { throw Failure.terminalOriginal }
    guard [.outside, .unloaded].contains(owned.presence),
      let physical = retained.physical, original.actor.system == flight.system,
      original.actor.visit <= flight.visit, original.issuedTime <= flight.physicalTime,
      let npc = retained.scriptNPC,
      same(reference.orientation.apply(npc.velocity), physical.velocity)
    else { throw Failure.invalidCondition }
    let world = ShipPose(
      position: reference.systemPoint(retained.position),
      orientation: retained.orientation.transformed(by: reference.orientation))
    let viewPosition = flight.pose.shipPoint(world.position)
    let viewBasis = world.orientation.relative(to: flight.pose.orientation)
    var candidate = retained
    candidate.position = station.orientation.inverse(viewPosition - station.position)
    candidate.orientation = viewBasis.relative(to: station.orientation)
    candidate.scriptNPC?.velocity = station.orientation.inverse(
      flight.pose.shipVector(physical.velocity))
    candidate.id = -1
    candidate.physical = nil
    guard validBody(candidate), let candidateNPC = candidate.scriptNPC else {
      throw Failure.invalidCondition
    }
    var view = candidate
    view.position = station.position + station.orientation.apply(candidate.position)
    view.orientation = candidate.orientation.transformed(by: station.orientation)
    guard same(rawPose(view, in: flight.pose), world),
      same(
        Game.modelPose(of: view, player: flight.pose),
        Game.modelPose(of: retained, player: reference)),
      same(
        flight.pose.orientation.apply(station.orientation.apply(candidateNPC.velocity)),
        physical.velocity)
    else { throw Failure.invalidCondition }
    return .init(
      original: original, logicalActor: owned.identity, alias: owned.alias, reference: reference,
      body: candidate, historicalPhysical: physical, worldRootPose: world)
  }

  /// A real receipt is necessary for this structural comparison, but not sufficient for source
  /// authority. The future private adapter must also validate its prepared source/condition patch.
  static func matchesActualAdmission(
    _ projection: AdmissionProjection, receipt: NativeMissionActorAdmissionReceipt,
    original: NativeHollowManifestOriginalSealBinding,
    owned: ScriptOwnedActor, body: SpaceBody, flight: FlightSimulationState
  ) -> Bool {
    compareAdmission(
      projection, receipt: receipt, original: original, owned: owned,
      body: body, flight: flight) == .matchingFacts
  }

  static func compareAdmission(
    _ projection: AdmissionProjection, receipt: NativeMissionActorAdmissionReceipt,
    original: NativeHollowManifestOriginalSealBinding,
    owned: ScriptOwnedActor, body: SpaceBody, flight: FlightSimulationState
  ) -> AdmissionComparison {
    guard
      preparedAdmissionMatches(
        projection, original: original, owned: owned, body: body, flight: flight)
    else { return .inconsistentFacts }
    guard receipt.nativeActors[owned.identity] == original.actor,
      receipt.sceneBodyIDs[owned.identity] == body.id
    else { return .foreignReceipt }
    return .matchingFacts
  }

  /// Structural checks against the actual private native plan, before its receipt exists.
  /// A true result grants no source authority or permission to publish that plan.
  static func preparedAdmissionMatches(
    _ projection: AdmissionProjection, original: NativeHollowManifestOriginalSealBinding,
    owned: ScriptOwnedActor, body: SpaceBody, flight: FlightSimulationState
  ) -> Bool {
    guard (try? validateFrame(flight, reference: projection.reference)) != nil,
      stableOriginal(projection.original, original), original.shapeValid,
      original.sourceRevision > projection.original.sourceRevision,
      original.issuedSequence > projection.original.issuedSequence,
      original.issuedTime >= projection.original.issuedTime,
      original.issuedTime <= flight.physicalTime, original.actor.system == flight.system,
      original.actor.visit == flight.visit,
      original.actor != projection.historicalPhysical.identity,
      owned.presence == .present, owned.identity == projection.logicalActor,
      owned.alias == projection.alias, owned.body.id == body.id,
      owned.body.physical?.identity == original.actor,
      (try? validateOriginal(body: body, owned: owned, original: original)) != nil,
      let physical = body.physical, let spawn = physical.spawnIdentity,
      spawn != projection.historicalPhysical.spawnIdentity,
      body.hull == projection.body.hull, body.energy == projection.body.energy,
      body.rotation == projection.body.rotation,
      body.rotationRate == projection.body.rotationRate,
      body.hostile == projection.body.hostile, body.missiles == projection.body.missiles,
      body.ecmEnabled == projection.body.ecmEnabled,
      physical.velocity == projection.historicalPhysical.velocity,
      physical.angularVelocity == projection.historicalPhysical.angularVelocity,
      physical.canonicalSpin == projection.historicalPhysical.canonicalSpin,
      physical.laserCooldown == projection.historicalPhysical.laserCooldown,
      same(flight.pose.systemPoint(body.position), projection.worldRootPose.position),
      same(
        body.orientation.transformed(by: flight.pose.orientation),
        projection.worldRootPose.orientation),
      let live = body.scriptNPC, let retained = projection.body.scriptNPC,
      live.fit == retained.fit, live.components == retained.components,
      live.fuel == retained.fuel, live.guns == retained.guns,
      live.shots == retained.shots,
      same(flight.pose.orientation.apply(live.velocity), physical.velocity),
      sameNativeCondition(physical.npc, projection.historicalPhysical.npc)
    else { return false }
    // Current route intent belongs to the separately validated G4 scheduler, not this helper.
    // The proposed retained actor must contain the same actual fresh condition as the body,
    // expressed in the fixed source frame. Matching only its new physical identity is insufficient.
    guard
      var captured = try? capture(
        body: body, owned: owned, original: original, flight: flight,
        reference: projection.reference),
      same(captured.position, owned.body.position),
      same(captured.orientation, owned.body.orientation),
      let velocity = captured.scriptNPC?.velocity,
      let retainedVelocity = owned.body.scriptNPC?.velocity,
      same(velocity, retainedVelocity)
    else { return false }
    captured.position = owned.body.position
    captured.orientation = owned.body.orientation
    captured.scriptNPC?.velocity = retainedVelocity
    guard captured == owned.body else { return false }
    return true
  }

  /// Structural saved-body validation; no source, native or life permission follows.
  static func retainedConditionShapeValid(_ body: SpaceBody) -> Bool {
    validBody(body)
  }

  /// Reuse the same strict frame guards for genuinely new source placement.
  static func validateAdmissionFrames(
    flight: FlightSimulationState, reference: ShipPose, station: SpaceBody
  ) throws {
    try validateFrame(flight, reference: reference)
    try validateStation(station, flight: flight)
  }

  private static func validateFrame(_ flight: FlightSimulationState, reference: ShipPose) throws {
    guard flight.valid, flight.system == NativeC03FreighterRoute.world,
      flight.player?.visit == flight.visit, let anchors = flight.anchors,
      anchors.system == flight.system, anchors.station.identity.visit == flight.visit,
      valid(flight.pose), valid(reference)
    else { throw Failure.invalidFrame }
  }

  private static func validateStation(_ station: SpaceBody, flight: FlightSimulationState) throws {
    guard station.id == 0, station.hull == .station, station.energy.isFinite, station.energy > 0,
      station.physical?.identity == flight.anchors?.station.identity,
      finite(station.position), proper(station.orientation),
      station.rotation.isFinite, station.rotationRate.isFinite
    else { throw Failure.invalidFrame }
  }

  private static func validateOriginal(
    body: SpaceBody, owned: ScriptOwnedActor, original: NativeHollowManifestOriginalSealBinding
  ) throws {
    guard original.shapeValid, owned.valid, validBody(owned.body), validBody(body),
      (1..<1_000_000_000).contains(body.id), owned.body.id == body.id,
      owned.body.hull == body.hull,
      owned.body.missionInstanceID == original.mission,
      body.missionInstanceID == original.mission, body.missionActorID == owned.identity,
      owned.body.missionActorID == owned.identity,
      owned.body.physical?.identity == original.actor,
      let physical = body.physical, physical.identity == original.actor,
      physical.population == .mission, physical.npc?.role == .mission,
      physical.npc?.resources?.valid == true,
      let spawn = physical.spawnIdentity, spawn.producer == .mission,
      spawn.system == original.actor.system, spawn.visit == original.actor.visit,
      spawn.sequence > 0, let npc = body.scriptNPC,
      npc.fit == owned.body.scriptNPC?.fit,
      npc.components.count == 1,
      npc.components[original.slot.rawValue]?.identity == original.component,
      npc.components.mapValues(\.identity) == owned.body.scriptNPC?.components.mapValues(\.identity)
    else { throw Failure.invalidOriginal }
  }

  private static func validBody(_ body: SpaceBody) -> Bool {
    guard finite(body.position), body.position.length <= 1e9, proper(body.orientation),
      body.rotation.isFinite, body.rotationRate.isFinite,
      body.energy.isFinite, body.energy >= 0,
      let npc = body.scriptNPC, npc.valid, body.energy <= npc.fit.definition.energy,
      body.scriptShot == nil, (0...32).contains(body.missiles),
      body.missiles <= npc.fit.definition.missiles
    else { return false }
    if let physical = body.physical {
      return finite(physical.velocity) && finite(physical.angularVelocity)
        && physical.laserCooldown.isFinite && physical.laserCooldown >= 0
        && physical.ordnance == nil && physical.rock == nil && physical.payload == nil
        && physical.salvage == nil && physical.empSource == nil && physical.empCrewPod == nil
    }
    return true
  }

  /// Only the existing admission policy may sanitize stale native AI addresses. This comparison
  /// preserves every other NPC condition field; it does not independently authorize that cleanup.
  private static func sameNativeCondition(_ a: NPCState?, _ b: NPCState?) -> Bool {
    guard var a, let b else { return a == b }
    a.firstAggressor = b.firstAggressor
    a.intention = b.intention
    return a == b
  }

  private static func stableOriginal(
    _ a: NativeHollowManifestOriginalSealBinding, _ b: NativeHollowManifestOriginalSealBinding
  ) -> Bool {
    a.slot == b.slot && a.mission == b.mission && a.owner == b.owner && a.source == b.source
      && a.hull == b.hull && a.captain == b.captain && a.seal == b.seal && a.master == b.master
      && a.imprint == b.imprint && a.component == b.component
  }
  private static func finite(_ v: Vector3) -> Bool { v.finite && v.length.isFinite }
  private static func valid(_ p: ShipPose) -> Bool {
    finite(p.position) && proper(p.orientation)
  }
  private static func same(_ a: Vector3, _ b: Vector3) -> Bool { (a - b).length <= 1e-7 }
  private static func same(_ a: Basis3, _ b: Basis3) -> Bool {
    (a.x - b.x).length <= 1e-9 && (a.y - b.y).length <= 1e-9 && (a.z - b.z).length <= 1e-9
  }
  private static func same(_ a: ShipPose, _ b: ShipPose) -> Bool {
    same(a.position, b.position) && same(a.orientation, b.orientation)
  }
  private static func rawPose(_ body: SpaceBody, in frame: ShipPose) -> ShipPose {
    .init(
      position: frame.systemPoint(body.position),
      orientation: body.orientation.transformed(by: frame.orientation))
  }
  /// Transpose-based frame conversions require a proper rotation. Never repair the caller's
  /// frozen frame; even small admitted errors must also pass each actual round-trip check.
  private static func proper(_ b: Basis3) -> Bool {
    b.finite && [b.x, b.y, b.z].allSatisfy { abs($0.length - 1) <= 1e-9 }
      && abs(b.x.dot(b.y)) <= 1e-9 && abs(b.x.dot(b.z)) <= 1e-9
      && abs(b.y.dot(b.z)) <= 1e-9 && abs(b.x.cross(b.y).dot(b.z) - 1) <= 1e-9
  }
}
