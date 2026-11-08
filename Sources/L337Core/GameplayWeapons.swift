import Foundation

/// Synchronous query facts; no Game copy or authority beyond the original physical contact.
private final class NPCBeamPreparation {
  let owner: ActorIdentity
  let launch: Vector3
  let contact: MissionCollisionContact?

  @inline(never)
  init(owner: ActorIdentity, launch: Vector3, contact: consuming MissionCollisionContact?) {
    self.owner = owner
    self.launch = launch
    self.contact = consume contact
  }
}

private struct NPCBeamAim {
  let owner: ActorIdentity
  let emitter: Vector3
  let direction: Vector3
  let launch: Vector3
}

/// Only the original flight snapshot can roll back a refused native mission impact.
private final class NPCBeamEmission {
  let preparation: NPCBeamPreparation
  let flightBeforeEmission: FlightSimulationState
  let origin: AttackOrigin

  @inline(never)
  init(
    preparation: NPCBeamPreparation, flightBeforeEmission: consuming FlightSimulationState,
    origin: AttackOrigin
  ) {
    self.preparation = preparation
    self.flightBeforeEmission = consume flightBeforeEmission
    self.origin = origin
  }
}

extension Game {
  static let combatLaserEnergyCost = 1.0
  /// Mount direction, hull intersections and legal attribution share the same
  /// physical frame; a targeting lock never makes a shot pass through a ship.
  mutating func fireLaser() {
    guard let mount = LaserMount.from(screen) else { return }
    fireLaser(mount: mount)
  }

  /// Autonomous fire uses the fitted mount without changing the user's view or selected tool.
  mutating func fireLaser(mount: LaserMount) {
    guard !playerEMPDisabled, fireCooldown <= 0, laserHeat < 240,
      energy > Self.combatLaserEnergyCost,
      let laser = commander.laser(on: mount)
    else { return }
    ensurePhysicalActors()
    let direction: Vector3
    switch mount {
    case .front: direction = .init(0, 0, 1)
    case .rear: direction = .init(0, 0, -1)
    case .left: direction = .init(-1, 0, 0)
    case .right: direction = .init(1, 0, 0)
    }
    let contact: MissionCollisionContact?
    do {
      contact = try nearestMissionCollision(
        from: .init(0, 0, 0), direction: direction, range: 6000, radius: 0,
        excludingBodyIDs: [], includePlayer: false)
    } catch { return }
    guard let player = commander.flightSimulation.player else { return }
    let damage: Double
    if let contact, case .body(let id) = contact.hit.target,
      let body = bodies.first(where: { $0.id == id })
    {
      damage = commander.laserDamage(against: body.hull, mount: mount)
    } else {
      damage = laser.damage
    }
    if let contact, contact.selectedTargetBody?.scriptNPC != nil {
      do {
        _ = try preflightNativeMissionContact(
          contact, owner: player, damage: damage, laser: laser, mount: mount)
      } catch { return }
    }
    let flightBeforeEmission = commander.flightSimulation
    guard let origin = makeAttackOrigin(owner: player) else { return }
    let emissionPosition = commander.flightSimulation.pose.position
    guard let contact else {
      recordPlayerLaserDischarge(laser, emission: origin.emissionID)
      recordCombat(
        origin: origin, kind: .laser, outcome: .discharge, target: nil,
        worldPosition: emissionPosition, emissionPosition: emissionPosition,
        laser: laser, mount: mount)
      commander.crimeLedger.finishEmission(origin.emissionID)
      return
    }
    let hit = contact.hit
    if handleNativePracticeContact(contact, origin: origin, kind: .laser) {
      recordPlayerLaserDischarge(laser, emission: origin.emissionID)
      commander.crimeLedger.finishEmission(origin.emissionID)
      return
    }
    if contact.selectedTargetBody?.scriptNPC != nil {
      do {
        let receipt = try applyNativeMissionContact(
          contact, origin: origin, damage: damage, laser: laser, mount: mount,
          emissionPosition: emissionPosition)
        projectScriptMissionImpact(receipt)
      } catch {
        commander.flightSimulation = flightBeforeEmission
        return
      }
    } else {
      applyCombatHit(
        hit, origin: origin, kind: .laser, damage: damage, laser: laser, mount: mount,
        emissionPosition: emissionPosition)
    }
    recordPlayerLaserDischarge(laser, emission: origin.emissionID)
    commander.crimeLedger.finishEmission(origin.emissionID)
  }

  private mutating func recordPlayerLaserDischarge(_ laser: LaserKind, emission: UInt64) {
    observeSafeGunneryDischarge(emission: emission)
    observeDefensiveFlightDischarge(emission: emission)
    fireCooldown = laser.firingInterval
    laserHeat += 10
    energy -= Self.combatLaserEnergyCost
    laserFlash = 0.08
    dischargeAudio.record(.combatLaser)
  }

  /// The real selected legacy source supplies its sealed query and completed
  /// motion proof. Re-query live availability in the original selected geometry
  /// at this actual source turn, then use the unchanged emission/effect owners.
  private mutating func emitSelectedLegacyNPCBeam(
    _ native: CurrentNewtLegacyEffectContext, bodyID: Int, damage: Double,
    energyMultiplier: Double
  ) {
    guard let plan = native.plan, plan.bodyID == bodyID,
      let query = querySelectedLegacyNPCBeam(
        plan, evidence: native.evidence,
        admittedAtEnd: native.admittedAtEnd)
    else { return }
    if let contact = query.contact, contact.selectedTargetBody?.scriptNPC != nil {
      guard
        (try? preflightSelectedNativeMissionContact(
          contact, owner: query.owner,
          damage: damage, evidence: native.evidence, admittedAtEnd: native.admittedAtEnd)) != nil
      else { return }
    }
    var retained = self
    let preparation = NPCBeamPreparation(
      owner: query.owner, launch: query.launch,
      contact: query.contact)
    guard let emission = retained.prepareNPCBeamEmission(preparation) else { return }
    var combatEffect: NativeCombatHitClockEffect?
    var missionEffect: NativeMissionBeamClockEffect?
    if let contact = query.contact {
      if contact.selectedTargetBody?.scriptNPC != nil {
        guard
          let applied = try? retained.applySelectedNativeMissionContact(
            contact,
            origin: emission.origin, damage: damage, emissionPosition: query.launch,
            evidence: native.evidence, admittedAtEnd: native.admittedAtEnd)
        else { return }
        retained.projectScriptMissionImpact(applied.receipt)
        missionEffect = applied.clockEffect
      } else {
        guard
          let applied = retained.applySelectedNativeNPCBeamHit(
            contact, origin: emission.origin,
            damage: damage, emissionPosition: query.launch, energyMultiplier: energyMultiplier,
            evidence: native.evidence, admittedAtEnd: native.admittedAtEnd)
        else { return }
        combatEffect = applied
      }
    } else {
      guard
        let applied = retained.recordNativeNPCDischarge(
          origin: emission.origin,
          position: query.launch)
      else { return }
      combatEffect = applied
    }
    retained.finishNPCBeam(emission, bodyID: bodyID, damage: damage)
    self = retained
    if let combatEffect { native.recordAccepted(combatEffect) }
    if let missionEffect { native.recordAccepted(missionEffect) }
  }

  /// NPC beams obey occlusion and record their real emitter; the encounter owns cadence/damage.
  /// Cold phases mutate the same live Game, without reserving their query values in this frame.
  @inline(never)
  mutating func emitLegacyNPCBeam(
    bodyID: Int, damage: Double, energyMultiplier: Double = 1,
    native: CurrentNewtLegacyEffectContext? = nil
  ) {
    if let native {
      emitSelectedLegacyNPCBeam(
        native, bodyID: bodyID, damage: damage,
        energyMultiplier: energyMultiplier)
      return
    }
    ensurePhysicalActors()
    guard let preparation = prepareNPCBeam(bodyID: bodyID, damage: damage),
      let emission = prepareNPCBeamEmission(preparation),
      applyNPCBeamImpact(emission, damage: damage, energyMultiplier: energyMultiplier)
    else { return }
    finishNPCBeam(emission, bodyID: bodyID, damage: damage)
  }

  @inline(never)
  private mutating func prepareNPCBeam(bodyID: Int, damage: Double) -> NPCBeamPreparation? {
    guard let aim = prepareNPCBeamAim(bodyID: bodyID) else { return nil }
    return prepareNPCBeamContact(aim, bodyID: bodyID, damage: damage)
  }

  @inline(never)
  private func prepareNPCBeamAim(bodyID: Int) -> NPCBeamAim? {
    guard let body = bodies.first(where: { $0.id == bodyID && $0.energy > 0 }),
      !isEMPDisabled(body),
      let owner = body.physical?.identity,
      body.position.length > 0
    else { return nil }
    let emitter: Vector3
    if body.isAegisPrototype, let muzzle = AegisPrototype.muzzle {
      emitter = body.position + body.modelVector(muzzle)
    } else {
      emitter = body.position
    }
    let aim = Self.nativePlayerSurfaceAim(from: emitter, mesh: nativeGuidanceStoredPlayerMesh())
    let direction = aim - emitter
    guard direction.finite, direction.length.isFinite, direction.length > 0 else { return nil }
    let launch = storedFlightSimulation().pose.systemPoint(emitter)
    return .init(owner: owner, emitter: emitter, direction: direction, launch: launch)
  }

  @inline(never)
  private func prepareNPCBeamContact(_ aim: NPCBeamAim, bodyID: Int, damage: Double) -> NPCBeamPreparation? {
    let owner = aim.owner
    let emitter = aim.emitter
    let direction = aim.direction
    let launch = aim.launch
    let contact: MissionCollisionContact?
    do {
      contact = try nearestMissionCollision(
        from: emitter, direction: direction.unit,
        range: direction.length + 1, radius: 0,
        excludingBodyIDs: [bodyID], includePlayer: true)
    } catch { return nil }
    if let contact, contact.selectedTargetBody?.scriptNPC != nil {
      do {
        _ = try preflightNativeMissionContact(
          contact, owner: owner, damage: damage, laser: nil, mount: nil)
      } catch { return nil }
    }
    return .init(owner: owner, launch: launch, contact: contact)
  }

  /// Triangle centres are real surface targets; a camera origin can lie in a hull opening.
  /// Other topology keeps the old origin aim and must still pass the native physical query.
  @inline(never)
  static func nativePlayerSurfaceAim(from origin: Vector3, mesh: borrowing Mesh) -> Vector3
  {
    var nearest = Vector3(0, 0, 0)
    var nearestRange = Double.infinity
    for face in mesh.faces where face.count == 3 {
      guard mesh.vertices.indices.contains(face[0]), mesh.vertices.indices.contains(face[1]),
        mesh.vertices.indices.contains(face[2])
      else { continue }
      let a = mesh.vertices[face[0]]
      let b = mesh.vertices[face[1]]
      let c = mesh.vertices[face[2]]
      guard a.finite, b.finite, c.finite else { continue }
      let normal = (b - a).cross(c - a)
      guard normal.length.isFinite, normal.length > 0 else { continue }
      let point = (a + b + c) * (1 / 3.0)
      let range = (point - origin).length
      guard point.finite, range.isFinite, range > 0 else { continue }
      if range < nearestRange {
        nearest = point
        nearestRange = range
      }
    }
    return nearest
  }

  @inline(never)
  private mutating func prepareNPCBeamEmission(_ preparation: NPCBeamPreparation)
    -> NPCBeamEmission?
  {
    let flightBeforeEmission = storedFlightSimulation()
    guard let origin = makeAttackOrigin(owner: preparation.owner) else { return nil }
    return .init(
      preparation: preparation, flightBeforeEmission: flightBeforeEmission, origin: origin)
  }

  @inline(never)
  private mutating func applyNPCBeamImpact(
    _ emission: NPCBeamEmission, damage: Double, energyMultiplier: Double
  ) -> Bool {
    if let contact = emission.preparation.contact {
      if contact.selectedTargetBody?.scriptNPC != nil {
        guard
          let receipt = try? applyNativeMissionContact(
            contact, origin: emission.origin, damage: damage, laser: nil, mount: nil,
            emissionPosition: emission.preparation.launch)
        else {
          commander.flightSimulation = emission.flightBeforeEmission
          return false
        }
        projectScriptMissionImpact(receipt)
      } else {
        applyCombatHit(
          contact.hit, origin: emission.origin, kind: .laser, damage: damage,
          emissionPosition: emission.preparation.launch,
          energyMultiplier: energyMultiplier)
      }
    } else {
      recordCombat(
        origin: emission.origin, kind: .laser, outcome: .discharge, target: nil,
        worldPosition: emission.preparation.launch, emissionPosition: emission.preparation.launch)
    }
    return true
  }

  @inline(never)
  private mutating func finishNPCBeam(_ emission: NPCBeamEmission, bodyID: Int, damage: Double) {
    if let index = bodies.firstIndex(where: { $0.id == bodyID }) {
      bodies[index].physical?.npc?.resources?.recordBeam(heat: min(10, damage * 10 / 15))
    }
    commander.crimeLedger.finishEmission(emission.origin.emissionID)
  }

  @discardableResult mutating func applyAttributedEnergyBomb() -> Bool {
    ensurePhysicalActors()
    guard let player = commander.flightSimulation.player,
      let origin = makeAttackOrigin(owner: player)
    else { return false }
    let launch = commander.flightSimulation.pose.position
    for body in bodies where body.energy > 0 && nativePracticeReservation(body) == nil {
      guard
        applyCombatHit(
          .init(target: .body(body.id), distance: body.position.length, point: body.position),
          origin: origin, kind: .bomb, damage: body.nativeNavalBombImmune ? 0 : body.energy,
          emissionPosition: launch) != nil
      else { return false }
      if let damaged = bodies.first(where: { $0.id == body.id }), damaged.energy <= 0,
        damaged.hull != .missile, damaged.physical?.deathIncidentID == nil
      {
        return false
      }
    }
    commander.crimeLedger.finishEmission(origin.emissionID)
    return true
  }

  /// Destruction created by an older scripted path uses the same once-only
  /// settlement. Already attributed damage must never receive a second bounty.
  mutating func settleLegacyCombatDeath(_ body: SpaceBody) {
    guard body.destroyedByPlayer == true, body.physical?.deathOrigin == nil,
      body.hull.isTargetShip, let player = commander.flightSimulation.player,
      let origin = makeAttackOrigin(owner: player)
    else { return }
    let destruction = recordCombat(
      origin: origin, kind: .laser, outcome: .destruction, target: .body(body.id),
      worldPosition: commander.flightSimulation.pose.systemPoint(body.position))
    if let index = bodies.firstIndex(where: { $0.id == body.id }) {
      bodies[index].physical?.deathOrigin = origin
      bodies[index].physical?.deathIncidentID = destruction?.id
    }
    commander.crimeLedger.finishEmission(origin.emissionID)
  }

  var gameplayMeshOverrides: [Int: Mesh] {
    var result: [Int: Mesh] = [:]
    for body in bodies {
      if body.physical?.currentNewtKitStock != nil { continue }
      if body.isAegisPrototype || nativePracticeReservation(body) != nil
        || body.physical?.catalogueShipID != nil || body.physical?.rock != nil
        || body.physical?.salvage?.lot != nil || body.nativeStationIdentity != nil
        || body.physical?.ordnance?.profile == .alienSeeker
      {
        result[body.id] = gameplayMesh(for: body)
      }
    }
    return result
  }

  func gameplayMesh(for body: SpaceBody) -> Mesh {
    if let mesh = currentOccupiedNewtPodMesh(body) { return mesh }
    precondition(!OriginalDetailedHullStage.blocksRuntime(body), "Pending original hull has no physical mesh")
    if let mesh = nativePracticeMesh(body) { return mesh }
    if body.physical?.ordnance?.profile == .alienSeeker { return AlienMissileMesh.mesh }
    if let identity = body.nativeStationIdentity {
      guard nativeStationBodyIsCurrent(body),
        let source = NativeStationSource.binding(for: identity)
      else { return .init(vertices: [], faces: []) }
      return source.geometry.mesh
    }
    return gameplayMeshAfterNativeStation(for: body)
  }

  @inline(never)
  mutating func nativeStationApproachGameplayMesh(for body: borrowing SpaceBody) -> Mesh {
    if let mesh = currentOccupiedNewtPodMesh(copy body) { return mesh }
    let pendingOriginalHull = OriginalDetailedHullStage.blocksRuntime(body)
    precondition(!pendingOriginalHull, "Pending original hull has no physical mesh")
    if body.physical?.ordnance?.profile == .alienSeeker { return AlienMissileMesh.mesh }
    if let identity = body.nativeStationIdentity {
      guard nativeStationApproachBodyIsCurrent(body),
        let source = NativeStationSource.binding(for: identity)
      else { return .init(vertices: [], faces: []) }
      return source.geometry.mesh
    }
    return gameplayMeshAfterNativeStation(for: body)
  }

  private func gameplayMeshAfterNativeStation(for body: SpaceBody) -> Mesh {
    if body.hull == .station { return MainStationGeometry.mesh }
    if body.hull == .constrictor {
      if body.isAegisPrototype, let mesh = AegisPrototype.mesh { return mesh }
      return .init(vertices: [], faces: [])
    }
    if let payload = body.physical?.payload, case .salvage(let identity) = payload,
      let lot = salvageLotForGeometry(identity)
    {
      let base = Mesh.hull(.cargo)
      let x = base.vertices.map { abs($0.x) }.max() ?? 1
      let y = base.vertices.map { abs($0.y) }.max() ?? 1
      let z = base.vertices.map { abs($0.z) }.max() ?? 1
      guard x > 0, y > 0, z > 0 else { return base }
      return .init(
        vertices: base.vertices.map {
          .init(
            $0.x * lot.halfExtents.x / x, $0.y * lot.halfExtents.y / y,
            $0.z * lot.halfExtents.z / z)
        }, faces: base.faces, details: base.details, materials: base.materials,
        faceMaterials: base.faceMaterials, faceTextures: base.faceTextures, preserveWinding: true)
    }
    if let id = body.physical?.catalogueShipID, let mesh = ShipCatalogue.rawMesh(id) {
      return mesh
    }
    // Retired discriminators cannot supply implicit collision geometry.
    guard body.hull != .cobra,
      !body.hull.isTargetShip || ShipCatalogue.nativeMesh(body.hull) != nil
    else { return .init(vertices: [], faces: []) }
    let base = Mesh.hull(body.hull)
    guard let identity = body.physical?.rock,
      let rock = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == identity })
    else { return base }
    let radius = base.vertices.map(\.length).max() ?? 1
    let scaled = Mesh(
      vertices: base.vertices.map { $0 * (rock.radius / radius) }, faces: base.faces,
      details: base.details, materials: base.materials, faceMaterials: base.faceMaterials,
      faceTextures: base.faceTextures, preserveWinding: true)
    return MiningRockAppearance.materials(for: rock, mesh: scaled)
  }
}
