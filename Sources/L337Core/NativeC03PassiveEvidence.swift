import Foundation

enum NativeC03PassiveEvidenceKind: Equatable, Sendable {
  case wakeMark(NativeC03WakeGeometry.Mark)
  case custodyArchive
}

extension Game {
  /// Classification for ship credit only. It grants no source, damage, custody or native
  /// permission. A stale/missing/mismatched claim returns nil and leaves combat policy alone.
  @inline(never)
  func c03PassiveEvidenceKind(of body: SpaceBody) -> NativeC03PassiveEvidenceKind? {
    guard let mission = body.missionInstanceID, let logical = body.missionActorID,
      let instance = hollowManifestMission, instance.id == mission,
      bodies.filter({ $0.id == body.id }) == [body],
      let physical = body.physical, physical.population == .mission,
      physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit,
      physical.npc?.role == .mission,
      let pin = try? hollowManifestInstalledCase(), pin.missionID == mission
    else { return nil }
    let kind: NativeC03PassiveEvidenceKind
    if let trail = pin.state.wakeTrail,
      let mark = NativeC03WakeGeometry.Mark.allCases.first(where: {
        logical == NativeC03WakeTrail.logicalActor(mission: mission, mark: $0)
      }), let admission = trail.latest(mark),
      let owned = instance.ownedEncounters[NativeC03WakeTrail.encounter]?.actors[mark.rawValue],
      c03PassiveEvidenceBodyMatches(
        body, owned: owned, actor: admission.actor, spawn: admission.spawn,
        profile: NativeC03WakeGeometry.profile(mark)),
      withReadOnlyScriptState({ $0.geometry[admission.geometry] }) == NativeC03WakeGeometry.design(mark)
    {
      kind = .wakeMark(mark)
    } else if let record = pin.state.custodyRegister, let admission = record.latest,
      logical == admission.logicalActor,
      let owned = instance.ownedEncounters[NativeC03RegisterState.encounter]?
        .actors[NativeC03CustodyRegisterContent.target],
      c03PassiveEvidenceBodyMatches(
        body, owned: owned, actor: admission.actor, spawn: admission.spawn,
        profile: NativeC03RegisterGeometry.profile),
      body.scriptNPC?.components[NativeC03RegisterGeometry.component]?.identity == admission.component,
      withReadOnlyScriptState({ $0.geometry[admission.rootGeometry] }) == NativeC03RegisterGeometry.rootDesign,
      withReadOnlyScriptState({ $0.geometry[admission.faceGeometry] }) == NativeC03RegisterGeometry.faceDesign
    {
      kind = .custodyArchive
    } else {
      return nil
    }
    guard acceptsHollowManifestInstalledCase(pin) else { return nil }
    return kind
  }

  private func c03PassiveEvidenceBodyMatches(
    _ body: SpaceBody, owned: ScriptOwnedActor, actor: ActorIdentity, spawn: SpawnIdentity,
    profile: ScriptNPCDefinition
  ) -> Bool {
    guard [.present, .destroyed].contains(owned.presence),
      owned.body.id == body.id, owned.identity == body.missionActorID,
      owned.body.missionInstanceID == body.missionInstanceID, owned.body.hull == body.hull,
      owned.body.physical?.identity == actor, owned.body.physical?.spawnIdentity == spawn,
      body.physical?.identity == actor, body.physical?.spawnIdentity == spawn,
      body.energy.isFinite, (0...profile.energy).contains(body.energy),
      let npc = body.scriptNPC, npc.valid, npc.fit == owned.body.scriptNPC?.fit,
      npc.fit.definition == profile, let resources = body.physical?.npc?.resources,
      resources.valid, resources.profile == .nativeHull, resources.energyCapacity == profile.energy
    else { return false }
    return true
  }
}
