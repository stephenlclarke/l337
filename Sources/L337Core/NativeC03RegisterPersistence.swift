import Foundation

extension Game {
  /// Recognition refuses unsafe removal only; names and UUIDs grant no native source.
  func c03RegisterRecognizedBodyIDs() -> Set<Int> {
    guard let owner = commander.equipmentOwnerID else { return [] }
    let mission = NativeHollowManifestCommission.mission(owner: owner)
    let actor = NativeC03RegisterState.logicalActor(mission: mission)
    return Set(bodies.filter { $0.missionInstanceID == mission && $0.missionActorID == actor }.map(\.id))
  }

  func isC03RegisterBody(_ body: SpaceBody) -> Bool {
    c03RegisterRecognizedBodyIDs().contains(body.id)
  }

  @inline(never)
  mutating func captureC03RegisterActor(unloading: Bool = false) throws {
    guard systemIdentity == NativeHollowManifestDefinition.registerWorld,
      let instance = hollowManifestMission, let record = instance.savedHollowManifest?.custodyRegister
    else { return }
    let pin = try hollowManifestInstalledCase()
    let flight = withReadOnlyCommander { $0.flightSimulation }
    guard let admission = record.latest,
      let expected = instance.ownedEncounters[NativeC03RegisterState.encounter],
      var actor = expected.actors[NativeC03CustodyRegisterContent.target]
    else { throw SaveError.invalidCommander }
    guard actor.presence == .present else { return }
    let matching = bodies.filter { $0.missionActorID == actor.identity }
    guard matching.count == 1, let body = matching.first,
      body.missionInstanceID == instance.id, body.id == actor.body.id,
      body.physical?.identity == admission.actor, body.physical?.spawnIdentity == admission.spawn,
      admission.actor.system == flight.system, admission.actor.visit == flight.visit,
      body.scriptNPC?.fit == actor.body.scriptNPC?.fit,
      body.energy.isFinite, body.energy >= 0
    else { throw SaveError.invalidCommander }
    actor.body = try NativeC03RegisterState.capture(body, reference: record.origin.reference, flight: flight)
    actor.presence = body.energy == 0 ? .destroyed : unloading ? .unloaded : .present
    var updated = expected
    updated.actors[NativeC03CustodyRegisterContent.target] = actor
    guard updated != expected else { return }
    var selected = instance
    selected.ownedEncounters[NativeC03RegisterState.encounter] = updated
    var candidate = commander
    candidate.scriptState.instances[instance.id] = selected
    guard NativeHollowManifestSave.validateClaims(candidate),
      acceptsHollowManifestInstalledCase(pin), commander.flightSimulation == flight,
      bodies.filter({ $0.id == body.id }) == [body]
    else { throw SaveError.invalidCommander }
    commander = candidate
  }

  @inline(never)
  mutating func recordC03RegisterRemoval(_ body: SpaceBody, destroyed: Bool) throws {
    let pin = try hollowManifestInstalledCase()
    guard systemIdentity == NativeHollowManifestDefinition.registerWorld,
      let instance = hollowManifestMission, let record = pin.state.custodyRegister,
      let admission = record.latest,
      body.missionInstanceID == instance.id, body.missionActorID == admission.logicalActor,
      body.physical?.identity == admission.actor, body.physical?.spawnIdentity == admission.spawn,
      bodies.filter({ $0.id == body.id }) == [body],
      let expected = instance.ownedEncounters[NativeC03RegisterState.encounter],
      var actor = expected.actors[NativeC03CustodyRegisterContent.target], actor.body.id == body.id,
      [.present, .destroyed].contains(actor.presence),
      body.energy.isFinite, body.energy >= 0, destroyed == (body.energy == 0)
    else { throw SaveError.invalidCommander }
    let captured = try NativeC03RegisterState.capture(
      body, reference: record.origin.reference, flight: commander.flightSimulation)
    if actor.presence == .destroyed {
      guard destroyed, actor.body == captured else { throw SaveError.invalidCommander }
      return
    }
    actor.body = captured
    actor.presence = destroyed ? .destroyed : .outside
    var selected = instance
    selected.ownedEncounters[NativeC03RegisterState.encounter]?
      .actors[NativeC03CustodyRegisterContent.target] = actor
    var candidate = commander
    candidate.scriptState.instances[instance.id] = selected
    guard NativeHollowManifestSave.validateClaims(candidate), acceptsHollowManifestInstalledCase(pin) else {
      throw SaveError.invalidCommander
    }
    commander = candidate
  }
}
