import Foundation

/// Structural coordinate checks only. Actual factories still read/recheck their Game-owned
/// case, native station, physical scene, clock, geometry and epoch before native publication.
enum NativeC03AnchorFrames {
  static func matches(
    canonical: SystemAnchors, current: EncounterContext,
    flight: FlightSimulationState, station: SpaceBody
  ) -> Bool {
    guard [NativeHollowManifestDefinition.freighterWorld,
      NativeHollowManifestDefinition.carrierWorld, NativeHollowManifestDefinition.registerWorld]
      .contains(canonical.system), flight.valid, flight.anchors == canonical,
      flight.system == canonical.system, current.system == canonical.system,
      current.visit == flight.visit, current.physicalTime == flight.physicalTime,
      current.player.identity == flight.player,
      current.player.position == flight.pose.position,
      current.player.orientation == flight.pose.orientation,
      canonical.station.identity.system == canonical.system,
      canonical.station.identity.visit == flight.visit, canonical.station.identity.entity == 1,
      current.anchors.system == canonical.system,
      current.anchors.station.identity == canonical.station.identity,
      current.anchors.planet == canonical.planet, current.anchors.sun == canonical.sun,
      current.anchors.arrival == canonical.arrival,
      station.id == 0, station.hull == .station, station.energy.isFinite, station.energy > 0,
      station.physical?.identity == canonical.station.identity,
      station.position.finite, station.orientation.validRotation,
      station.rotation.isFinite, station.rotationRate.isFinite,
      flight.pose.position.finite, flight.pose.orientation.validRotation,
      canonical.station.orientation.validRotation,
      canonical.station.exitPosition.finite, canonical.station.exitDirection.finite,
      canonical.station.position.finite, current.anchors.station.position.finite,
      canonical.planet.position.finite, canonical.sun.position.finite,
      canonical.planet.radius.isFinite, canonical.planet.radius > 0,
      canonical.sun.radius.isFinite, canonical.sun.radius > 0,
      canonical.arrival.finite
    else { return false }
    let pose = Game.modelPose(of: station, player: flight.pose)
    let observed = current.anchors.station
    let normal = flight.pose.orientation.apply(station.entranceNormal)
    let exit = flight.pose.systemPoint(station.entrancePosition) + normal * 400
    // Canonical centres/spheres locate the fixed source layout. The instantaneous model phase
    // and entrance belong to the actual projected station, not the canonical anchor's axes.
    // These round-trip tolerances match existing C03 retained position/basis projections.
    return (observed.position - canonical.station.position).length <= 1e-7
      && (pose.position - observed.position).length <= 1e-7
      && observed.orientation.validRotation
      && (pose.orientation.x - observed.orientation.x).length <= 1e-9
      && (pose.orientation.y - observed.orientation.y).length <= 1e-9
      && (pose.orientation.z - observed.orientation.z).length <= 1e-9
      && exit.finite && normal.finite
      && (observed.exitPosition - exit).length <= 1e-7
      && (observed.exitDirection - normal).length <= 1e-9
  }
}
