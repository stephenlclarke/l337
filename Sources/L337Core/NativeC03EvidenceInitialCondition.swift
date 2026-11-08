import Foundation

/// Fresh condition recipes for the two closed passive evidence kinds. These issue no actor
/// or authority and never run on a retained source, so they cannot refill or migrate one.
enum NativeC03EvidenceInitialCondition {
  enum Kind { case wakeFragment, custodyArchive }

  static func state(for kind: Kind) -> NPCState {
    let world: SystemIdentity
    let capacity: Double
    switch kind {
    case .wakeFragment:
      world = NativeC03WakeGeometry.world
      capacity = NativeC03WakeGeometry.profile(.first).energy
    case .custodyArchive:
      world = NativeHollowManifestDefinition.registerWorld
      capacity = NativeC03RegisterGeometry.profile.energy
    }
    var condition = NPCState(role: .mission, origin: world, destination: world)
    condition.hasFuelScoops = false
    condition.resources = .init(
      profile: .nativeHull, energyCapacity: capacity, energyRecharge: 0,
      frontCapacity: 0, rearCapacity: 0, shieldRecharge: 0, frontShield: 0, rearShield: 0,
      heatCapacity: 0, heatCooling: 0, fuel: 0, fuelCapacity: 0)
    return condition
  }
}
