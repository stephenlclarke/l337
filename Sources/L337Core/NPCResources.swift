import Foundation

/// Per-craft readings in simulation units. Legacy mission hulls remain energy-only.
public struct NPCResources: Equatable, Codable, Sendable {
  public enum Profile: String, Codable, Sendable { case nativeHull, legacyEnergyOnly }
  public let profile: Profile
  public let energyCapacity: Double
  public let energyRecharge: Double
  public let frontCapacity: Double
  public let rearCapacity: Double
  public let shieldRecharge: Double
  public var frontShield: Double
  public var rearShield: Double
  public var laserHeat: Double = 0
  public let heatCapacity: Double
  public let heatCooling: Double
  /// nil preserves an unrecorded legacy tank; it never means a full tank.
  public var fuel: Int?
  public let fuelCapacity: Int?
  public var scoopRemainder: Double = 0
  public var electrical: ElectricalReserve? = nil
  var electricalRecharge: Double { energyRecharge }

  public var valid: Bool {
    let fuelValid: Bool
    if let capacity = fuelCapacity {
      fuelValid =
        (0...10000).contains(capacity)
        && (fuel.map { $0 >= 0 && $0 <= capacity } ?? true)
    } else {
      fuelValid = fuel == nil
    }
    return [
      energyCapacity, energyRecharge, frontCapacity, rearCapacity, shieldRecharge,
      frontShield, rearShield, laserHeat, heatCapacity, heatCooling, scoopRemainder,
    ]
    .allSatisfy { $0.isFinite && $0 >= 0 }
      && energyCapacity > 0 && energyCapacity <= 100000
      && frontShield <= frontCapacity && rearShield <= rearCapacity
      && laserHeat <= heatCapacity && scoopRemainder < 1
      && fuelValid
      && (electrical.map {
        $0.valid && $0.capacity == energyCapacity && $0.recharge == electricalRecharge
      } ?? true)
  }

  public static func stock(_ performance: ShipPerformance) -> NPCResources? {
    guard performance.valid else { return nil }
    return .init(
      profile: .nativeHull, energyCapacity: performance.energy,
      energyRecharge: performance.recharge, frontCapacity: performance.shield,
      rearCapacity: performance.shield, shieldRecharge: performance.shieldRecharge,
      frontShield: performance.shield, rearShield: performance.shield,
      heatCapacity: 240, heatCooling: 12,
      fuel: performance.fuel, fuelCapacity: performance.fuel)
  }

  public static func legacyEnergyOnly(maximumEnergy: Double) -> NPCResources? {
    guard maximumEnergy.isFinite, maximumEnergy > 0, maximumEnergy <= 100000 else { return nil }
    return .init(
      profile: .legacyEnergyOnly, energyCapacity: maximumEnergy, energyRecharge: 0,
      frontCapacity: 0, rearCapacity: 0, shieldRecharge: 0,
      frontShield: 0, rearShield: 0, heatCapacity: 240, heatCooling: 12,
      fuel: nil, fuelCapacity: nil)
  }

  public mutating func advance(delta: Double) {
    guard valid, delta.isFinite, delta > 0 else { return }
    frontShield = min(frontCapacity, frontShield + delta * shieldRecharge)
    rearShield = min(rearCapacity, rearShield + delta * shieldRecharge)
    laserHeat = max(0, laserHeat - delta * heatCooling)
  }

  public var canFire: Bool {
    valid && (profile == .legacyEnergyOnly || heatCapacity - laserHeat >= 10)
  }

  public mutating func recordBeam(heat: Double) {
    guard valid, heat.isFinite, heat > 0 else { return }
    laserHeat = min(heatCapacity, laserHeat + heat)
  }

  /// Returns hull damage after absorbing the actual struck facing's charge.
  public mutating func absorb(_ damage: Double, front: Bool) -> Double {
    guard valid, damage.isFinite, damage > 0 else { return damage }
    let absorbed = min(damage, front ? frontShield : rearShield)
    if front { frontShield -= absorbed } else { rearShield -= absorbed }
    return damage - absorbed
  }

  /// Fuel changes only for an admitted jump or actual scoop collection, never cruising.
  public mutating func spendFuel(_ tenthsLY: Int) -> Bool {
    guard valid, tenthsLY >= 0, let fuel, fuel >= tenthsLY else { return false }
    self.fuel = fuel - tenthsLY
    return true
  }

  public mutating func scoopFuel(delta: Double, rate: Double) {
    guard valid, delta.isFinite, delta > 0, rate.isFinite, rate > 0,
      let fuel, let capacity = fuelCapacity, fuel < capacity
    else { return }
    let collected = scoopRemainder + min(Double(capacity - fuel), delta * rate)
    let units = Int(collected)
    self.fuel = min(capacity, fuel + units)
    scoopRemainder = self.fuel == capacity ? 0 : collected - Double(units)
  }

  public var telemetry: TargetTelemetry.Resources {
    .init(
      frontShield: frontShield, frontCapacity: frontCapacity,
      rearShield: rearShield, rearCapacity: rearCapacity,
      laserHeat: laserHeat, heatCapacity: heatCapacity,
      fuelTenthsLY: fuel ?? -1, fuelCapacityTenthsLY: fuelCapacity ?? -1,
      electricalPower: electrical?.remaining, electricalCapacity: electrical?.capacity)
  }
}

extension NPCResources {
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case profile, energyCapacity, energyRecharge, frontCapacity, rearCapacity, shieldRecharge
    case frontShield, rearShield, laserHeat, heatCapacity, heatCooling, fuel, fuelCapacity
    case scoopRemainder, electrical
  }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: ResourceKey.self)
    let allowed = Set(CodingKeys.allCases.map(\.rawValue))
    guard Set(fields.allKeys.map(\.stringValue)).isSubset(of: allowed) else {
      throw SaveError.invalidCommander
    }
    let values = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      profile: try values.decode(Profile.self, forKey: .profile),
      energyCapacity: try values.decode(Double.self, forKey: .energyCapacity),
      energyRecharge: try values.decode(Double.self, forKey: .energyRecharge),
      frontCapacity: try values.decode(Double.self, forKey: .frontCapacity),
      rearCapacity: try values.decode(Double.self, forKey: .rearCapacity),
      shieldRecharge: try values.decode(Double.self, forKey: .shieldRecharge),
      frontShield: try values.decode(Double.self, forKey: .frontShield),
      rearShield: try values.decode(Double.self, forKey: .rearShield),
      laserHeat: try values.decode(Double.self, forKey: .laserHeat),
      heatCapacity: try values.decode(Double.self, forKey: .heatCapacity),
      heatCooling: try values.decode(Double.self, forKey: .heatCooling),
      fuel: try values.decodeIfPresent(Int.self, forKey: .fuel),
      fuelCapacity: try values.decodeIfPresent(Int.self, forKey: .fuelCapacity),
      scoopRemainder: try values.decode(Double.self, forKey: .scoopRemainder),
      electrical: try values.decodeIfPresent(ElectricalReserve.self, forKey: .electrical))
  }

  private struct ResourceKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
  }
}

public enum NPCFactProvenance: String, Codable, Sendable { case generated, recorded, inferredLocal }
