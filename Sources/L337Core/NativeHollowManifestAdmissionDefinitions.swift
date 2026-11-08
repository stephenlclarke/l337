import Foundation

extension NativeHollowManifestCommission {
  private static func installedAdmissionDeclarations(
    pack: borrowing ScriptPack, state: borrowing ScriptInstance
  ) -> (
    encounter: ScriptEncounterDefinition, profiles: [ScriptNPCDefinition],
    designs: [String: ShipDesign]
  )? {
    guard matches(pack), state.definition == stateID, state.digest == digest,
      prefixValid(state), admittedActorClaimsMatch(state),
      let saved = state.savedHollowManifest, let frame = saved.sourceFrame,
      let anchors = saved.routeAnchors, let encounter = saved.ownedEncounterID
    else { return nil }
    return try? admissionDeclarations(
      birth: saved.birth, anchors: anchors,
      sourceFrame: frame, encounter: encounter)
  }

  static func encounterDefinition(pack: ScriptPack, state: ScriptInstance, id: String)
    -> ScriptEncounterDefinition?
  {
    if marked(state) || applies(pack) {
      if id == NativeC03CrewSourceState.encounter {
        return NativeC03EvacuationDefinitions.installed(pack: pack, state: state)?.encounter
      }
      if id == NativeC03RegisterState.encounter,
        installedAdmissionDeclarations(pack: pack, state: state) != nil,
        state.savedHollowManifest?.custodyRegister != nil {
        return NativeC03RegisterGeometry.declaration
      }
      if id == NativeC03WakeTrail.encounter,
        installedAdmissionDeclarations(pack: pack, state: state) != nil,
        let trail = state.savedHollowManifest?.wakeTrail {
        return try? NativeC03WakeGeometry.declaration(anchors: trail.origin.anchors)
      }
      guard id == encounter else { return nil }
      return installedAdmissionDeclarations(pack: pack, state: state)?.encounter
    }
    return NativeC01Surveyor.encounterDefinition(pack: pack, state: state, id: id)
  }

  static func profiles(pack: borrowing ScriptPack, state: borrowing ScriptInstance)
    -> [ScriptNPCDefinition]
  {
    if marked(state) || applies(pack) {
      guard let declared = installedAdmissionDeclarations(pack: pack, state: state) else { return [] }
      let evacuation = NativeC03EvacuationDefinitions.installed(pack: pack, state: state)
      if state.savedHollowManifest?.crewSource != nil && evacuation == nil { return [] }
      return declared.profiles + (evacuation?.profiles ?? [])
        + (state.savedHollowManifest?.wakeTrail == nil ? []
        : NativeC03WakeGeometry.Mark.allCases.map(NativeC03WakeGeometry.profile))
        + (state.savedHollowManifest?.custodyRegister == nil ? [] : [NativeC03RegisterGeometry.profile])
    }
    return NativeC01Surveyor.profiles(pack: pack, state: state)
  }

  static func designs(pack: borrowing ScriptPack, state: borrowing ScriptInstance) -> [String:
    ShipDesign]
  {
    if marked(state) || applies(pack) {
      guard let declared = installedAdmissionDeclarations(pack: pack, state: state) else { return [:] }
      var values = declared.designs
      let evacuation = NativeC03EvacuationDefinitions.installed(pack: pack, state: state)
      if state.savedHollowManifest?.crewSource != nil && evacuation == nil { return [:] }
      for (model, design) in evacuation?.designs ?? [:] { values[model] = design }
      if state.savedHollowManifest?.wakeTrail != nil {
        for mark in NativeC03WakeGeometry.Mark.allCases {
          values[mark.model] = NativeC03WakeGeometry.design(mark)
        }
      }
      if state.savedHollowManifest?.custodyRegister != nil {
        values[NativeC03RegisterGeometry.rootModel] = NativeC03RegisterGeometry.rootDesign
        values[NativeC03RegisterGeometry.faceModel] = NativeC03RegisterGeometry.faceDesign
      }
      return values
    }
    return NativeC01Surveyor.designs(pack: pack, state: state)
  }
}
