import Foundation

/// Explicit new C03 local rescue fits. R3 engineering supplies maximum performance, not
/// automatically fitted weapons, fuel, shields, cabins, people or service capabilities.
enum NativeC03EvacuationProfile {
  typealias Role = NativeC03EvacuationHull.Role

  static func model(_ role: Role) -> String {
    role == .carrier ? "asset:c03-original-damaged-carrier" : "asset:c03-original-evacuation-launch"
  }

  static func definition(_ role: Role) throws -> ScriptNPCDefinition {
    let hull = try NativeC03EvacuationHull.resolve(role)
    let p = hull.source.performance
    let profile = ScriptNPCDefinition(
      id: role == .carrier ? "c03-original-damaged-carrier" : "c03-original-evacuation-launch",
      name: role == .carrier ? "Original damaged carrier" : "Original evacuation launch",
      source: hull.source.current.sourceSHA256,
      basis: "New C03 local unarmed/unshielded rescue source fit; no fuel or included role kit; current native units.",
      model: model(role), scale: 1, energy: Double(p.energy), recharge: p.recharge,
      speed: p.speed, acceleration: p.acceleration, pitch: p.pitch, yaw: p.yaw, roll: p.roll,
      missiles: 0, fuel: 0, drive: nil, ecm: false, bounty: 0, lasers: [], components: [])
    guard profile.valid else { throw SaveError.invalidCommander }
    return profile
  }

  static func initialHullEnergy(_ role: Role) throws -> Double {
    let capacity = try definition(role).energy
    // New authored initial condition; no combat incident is invented for prior story damage.
    return role == .carrier ? capacity * 0.5 : capacity
  }

  static func initialNativeCondition(_ role: Role) throws -> NPCState {
    let profile = try definition(role)
    let world = NativeHollowManifestDefinition.carrierWorld
    var condition = NPCState(role: .mission, origin: world, destination: world)
    condition.hasFuelScoops = false
    condition.resources = .init(
      profile: .nativeHull, energyCapacity: profile.energy, energyRecharge: profile.recharge,
      frontCapacity: 0, rearCapacity: 0, shieldRecharge: 0, frontShield: 0, rearShield: 0,
      heatCapacity: 0, heatCooling: 0, fuel: 0, fuelCapacity: 0)
    return condition
  }
}
