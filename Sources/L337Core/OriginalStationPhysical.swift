import Foundation

/// Factual values from one original station profile. These values confer no live
/// site, docking, damage, service or collection authority.
struct OriginalStationPhysical: Sendable, Equatable {
  let blueprintID: String
  let dryMassKilograms: Double
  let maximumStructuralEnergy: Double
  let rechargeEnergyPerSecond: Double

  private init(blueprintID: String, mass: Double, energy: Double, recharge: Double) {
    self.blueprintID = blueprintID
    dryMassKilograms = mass
    maximumStructuralEnergy = energy
    rechargeEnergyPerSecond = recharge
  }

  static func read(from ship: borrowing CatalogueShip) -> Self? {
    read(blueprintID: ship.id, profiles: ship.profiles)
  }

  static func read(blueprintID: String, profiles: borrowing [ShipProfile]) -> Self? {
    guard ["SH141", "SH034", "SH102"].contains(blueprintID) else { return nil }
    let profileID = "ORIGINAL-STATION-R3-" + blueprintID
    var profileIDs: Set<String> = []
    var selected: ShipProfile?
    for index in profiles.indices {
      let profile = profiles[index]
      guard profileIDs.insert(profile.id).inserted else { return nil }
      if profile.id == profileID || profile.group == "original-station-r3" {
        guard selected == nil, profile.id == profileID,
          profile.group == "original-station-r3"
        else { return nil }
        selected = profile
      }
    }
    guard let selected else { return nil }
    var keys: Set<String> = []
    var mass: Double?
    var energy: Double?
    var recharge: Double?
    for field in selected.fields {
      guard keys.insert(field.key).inserted else { return nil }
      switch field.key {
      case "original.physical.dryMassKilograms":
        guard field.unit == "kg", let value = field.number, value.isFinite, value > 0
        else { return nil }
        mass = value
      case "hull_energy":
        guard field.unit == "project units", let value = field.number,
          value.isFinite, value > 0
        else { return nil }
        energy = value
      case "energy_recharge_per_second":
        guard field.unit == "project units/s", let value = field.number,
          value.isFinite, value == 0
        else { return nil }
        recharge = value
      default: break
      }
    }
    guard let mass, let energy, let recharge else { return nil }
    return .init(blueprintID: blueprintID, mass: mass, energy: energy, recharge: recharge)
  }
}
