import Foundation

/// The one current declaration used by source preparation and retained native descriptor
/// resolution. These values grant no hull, person, native fitting or loaded-mass permission.
enum NativeC03EvacuationDefinitions {
  struct Values: Sendable {
    let encounter: ScriptEncounterDefinition
    let profiles: [ScriptNPCDefinition]
    let designs: [String: ShipDesign]
  }

  private static let current = Result { try prepare() }

  static func resolve() throws -> Values { try current.get() }

  /// Actual installed retention is required before the ordinary native descriptor factory
  /// may see this declaration. Full source/custody/current-body checks remain separate.
  static func installed(pack: borrowing ScriptPack, state: borrowing ScriptInstance) -> Values? {
    guard NativeHollowManifestCommission.matches(pack),
      NativeHollowManifestCommission.marked(state),
      NativeHollowManifestCommission.prefixValid(state),
      NativeHollowManifestCommission.admittedActorClaimsMatch(state),
      state.savedHollowManifest?.crewSource != nil,
      state.ownedEncounters[NativeC03CrewSourceState.encounter]?.admitted == true
    else { return nil }
    return try? resolve()
  }

  private static func prepare() throws -> Values {
    var profiles: [ScriptNPCDefinition] = []
    var designs: [String: ShipDesign] = [:]
    var actors: [ScriptActorDefinition] = []
    for role in NativeC03EvacuationHull.Role.allCases {
      let hull = try NativeC03EvacuationHull.resolve(role)
      let profile = try NativeC03EvacuationProfile.definition(role)
      profiles.append(profile)
      designs[NativeC03EvacuationProfile.model(role)] = hull.design
      actors.append(.init(
        id: role == .launch ? NativeC03CrewSourceState.launchTarget : NativeC03CrewSourceState.carrierTarget,
        hull: nil, npc: profile.id, x: role == .launch ? 1000 : -1000, y: 0, z: 0, hostile: false))
    }
    let encounter = ScriptEncounterDefinition(id: NativeC03CrewSourceState.encounter,
      galaxy: NativeHollowManifestDefinition.carrierWorld.galaxy,
      system: NativeHollowManifestDefinition.carrierWorld.system,
      profile: "profiled-local-freeze-v1", actors: actors)
    guard profiles.count == 2, designs.count == 2, encounter.valid else {
      throw SaveError.invalidCommander
    }
    return .init(encounter: encounter, profiles: profiles, designs: designs)
  }
}
