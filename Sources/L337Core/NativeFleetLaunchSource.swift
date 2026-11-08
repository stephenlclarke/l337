import Foundation

/// The native initial cohort owns its existing actor and disposition, never an ambient request.
enum NativeFleetLaunchSource {
  static let traderShipID = OriginalOkapiActivation.id

  static func resolve(
    role: NPCRole, actor: ActorIdentity, seed: UInt64, context: EncounterContext,
    position: Vector3
  ) -> OriginalFleetRuntimeHullSource.Source? {
    guard actor.system == context.system, actor.visit == context.visit,
      position.finite, role == .trader || role == .pirate
    else { return nil }
    if role == .pirate {
      return OriginalFleetRuntimeHullSource.naturalSource(
        role: .pirate, context: context, positions: [position],
        draw: AmbientEncounterPolicy.nativeLaunchWord(actor: actor, seed: seed))
    }
    // The launch cohort is placed outside station protection while its player is departing.
    // Validate the actual hull's published placement, not an ambient decision at the player.
    guard let source = OriginalFleetRuntimeHullSource.source(for: traderShipID),
      source.ship.catalogue.readyForNaturalEncounters,
      source.ship.catalogue.encounterWeight(for: .trader) > 0,
      source.ship.catalogue.galaxies.contains(context.system.galaxy),
      source.ship.catalogue.regions.contains(
        EncounterGeography.region(at: position, anchors: context.anchors)),
      source.ship.catalogue.habitat == nil
    else { return nil }
    return source
  }
}
