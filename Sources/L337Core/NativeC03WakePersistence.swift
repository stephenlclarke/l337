import Foundation

extension Game {
  /// Recognition can refuse removal only. It is not an original source/admission capability.
  func c03WakeRecognizedBodyIDs() -> Set<Int> {
    guard let owner = commander.equipmentOwnerID else { return [] }
    let mission = NativeHollowManifestCommission.mission(owner: owner)
    let actors = Set(NativeC03WakeGeometry.Mark.allCases.map {
      NativeC03WakeTrail.logicalActor(mission: mission, mark: $0)
    })
    return Set(bodies.filter {
      $0.missionInstanceID == mission && $0.missionActorID.map(actors.contains) == true
    }.map(\.id))
  }

  func isC03WakeBody(_ body: SpaceBody) -> Bool {
    c03WakeRecognizedBodyIDs().contains(body.id)
  }

  /// Retain the actual source-owned fragments in their frozen inertial frame before writers,
  /// unload or cull. Missing live bodies refuse; absence is not death or permission to respawn.
  @inline(never)
  mutating func captureC03WakeActors(unloading: Bool = false) throws {
    guard systemIdentity == NativeC03WakeGeometry.world,
      let instance = hollowManifestMission, let trail = instance.savedHollowManifest?.wakeTrail
    else { return }
    let pin = try hollowManifestInstalledCase()
    let flight = withReadOnlyCommander { $0.flightSimulation }
    guard flight.valid, let player = flight.player, player.system == NativeC03WakeGeometry.world,
      let expected = instance.ownedEncounters[NativeC03WakeTrail.encounter]
    else { throw SaveError.invalidCommander }
    var updated = expected
    var observed: [SpaceBody] = []
    for mark in NativeC03WakeGeometry.Mark.allCases {
      guard var actor = updated.actors[mark.rawValue], let admission = trail.latest(mark) else {
        throw SaveError.invalidCommander
      }
      guard actor.presence == .present else { continue }
      let matching = bodies.filter { $0.missionActorID == actor.identity }
      guard matching.count == 1, let body = matching.first,
        body.missionInstanceID == instance.id, body.id == actor.body.id,
        body.physical?.identity == admission.actor, body.physical?.spawnIdentity == admission.spawn,
        admission.actor.visit == player.visit,
        body.scriptNPC?.fit == actor.body.scriptNPC?.fit,
        body.energy.isFinite, body.energy >= 0
      else { throw SaveError.invalidCommander }
      observed.append(body)
      actor.body = try NativeC03WakeTrail.capture(body, reference: trail.origin.reference, flight: flight)
      actor.presence = body.energy == 0 ? .destroyed : unloading ? .unloaded : .present
      updated.actors[mark.rawValue] = actor
    }
    guard updated != expected else { return }
    var selected = instance
    selected.ownedEncounters[NativeC03WakeTrail.encounter] = updated
    var candidate = commander
    candidate.scriptState.instances[instance.id] = selected
    guard NativeHollowManifestSave.validateClaims(candidate),
      acceptsHollowManifestInstalledCase(pin), commander.flightSimulation == flight,
      observed.allSatisfy({ body in bodies.filter({ $0.id == body.id }) == [body] })
    else { throw SaveError.invalidCommander }
    commander = candidate
  }

  /// The actual removal owner supplies its still-present body. No named replacement, catalogue
  /// asset, disappearance or raw energy flag outside the current scene is accepted.
  @inline(never)
  mutating func recordC03WakeActorRemoval(_ body: SpaceBody, destroyed: Bool) throws {
    let pin = try hollowManifestInstalledCase()
    guard systemIdentity == NativeC03WakeGeometry.world,
      let instance = hollowManifestMission, let trail = pin.state.wakeTrail,
      let mark = NativeC03WakeGeometry.Mark.allCases.first(where: {
        body.missionActorID == NativeC03WakeTrail.logicalActor(mission: instance.id, mark: $0)
      }),
      let admission = trail.latest(mark), body.missionInstanceID == instance.id,
      body.physical?.identity == admission.actor, body.physical?.spawnIdentity == admission.spawn,
      bodies.filter({ $0.id == body.id }) == [body],
      let expected = instance.ownedEncounters[NativeC03WakeTrail.encounter],
      var actor = expected.actors[mark.rawValue], actor.body.id == body.id,
      [.present, .destroyed].contains(actor.presence),
      destroyed == (body.energy == 0), body.energy.isFinite, body.energy >= 0
    else { throw SaveError.invalidCommander }
    let captured = try NativeC03WakeTrail.capture(
      body, reference: trail.origin.reference, flight: commander.flightSimulation)
    if actor.presence == .destroyed {
      guard destroyed, actor.body == captured else { throw SaveError.invalidCommander }
      return
    }
    actor.body = captured
    actor.presence = destroyed ? .destroyed : .outside
    var selected = instance
    selected.ownedEncounters[NativeC03WakeTrail.encounter]?.actors[mark.rawValue] = actor
    var candidate = commander
    candidate.scriptState.instances[instance.id] = selected
    guard NativeHollowManifestSave.validateClaims(candidate), acceptsHollowManifestInstalledCase(pin)
    else { throw SaveError.invalidCommander }
    commander = candidate
  }
}
