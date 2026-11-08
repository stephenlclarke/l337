import Foundation

/// Authenticated configuration-specific load distributions. Counts/readings are
/// never converted into mass unless the same source declares the unit and position.
struct CurrentNewtKitLoadModel: Sendable {
  enum Field: String, Sendable { case cargo, fuel, missiles, ecm }
  struct Allocation: Sendable {
    let id: String
    let mass: CurrentNewtKitReceipt.MassProperties
    let mesh: Mesh
    let offset: Vector3

    init(id: String, mass: CurrentNewtKitReceipt.MassProperties, mesh: Mesh,
      offset: Vector3 = .init(0, 0, 0)) {
      self.id = id
      self.mass = mass
      self.mesh = mesh
      self.offset = offset
    }
  }

  struct Rule: Sendable {
    let field: Field
    let commodity: CommodityIdentity?
    let unit: CurrentNewtKitReceipt.MassProperties
    let centres: [Vector3]
    let distributed: Bool
    let nativeUnit: String?
    let alwaysPresent: Bool
    let allocations: [Allocation]
  }

  let catalogueShipID: String
  let r3SHA256: String
  let rules: [Rule]
  let fixed: [CurrentNewtKitReceipt.MassProperties]
  let fixedAllocations: [Allocation]
  let maximumCargoMassKilograms: Double
  let maximumFuelTenthsLY: Double
  let maximumMissiles: Int

  static func decode(_ value: Any?) -> Self? {
    guard let root = value as? [String: Any], let catalogue = root["catalogueShipID"] as? String,
      let r3 = root["r3SHA256"] as? String, r3.utf8.count == 64,
      let entries = root["rules"] as? [[String: Any]], !entries.isEmpty,
      root["schema"] as? String == "l337.current-newt-actual-load/1",
      let fixedValues = root["fixedComponents"] as? [[String: Any]],
      let maximumCargo = root["maximumCargoMassKilograms"] as? Double,
      let maximumFuel = root["maximumFuelIncludingScoopRemainderTenthsLY"] as? Double,
      let maximumMissiles = root["maximumMissiles"] as? Int,
      root["requiredHasFuelScoops"] as? Bool == false,
      root["enableStateDoesNotRemoveInstalledECM"] as? Bool == true
    else { return nil }
    var rules: [Rule] = []
    for entry in entries {
      guard let fieldName = entry["field"] as? String, let field = Field(rawValue: fieldName),
        let rawMass = entry["unitMass"] as? [String: Any],
        let mass = CurrentNewtKitGeometry.mass(part: rawMass),
        let dimensions = entry["unitEnvelopeMetres"] as? [Double], dimensions.count == 3,
        dimensions.allSatisfy({ $0.isFinite && $0 > 0 }),
        let positions = entry["centresMetres"] as? [[Double]], !positions.isEmpty,
        positions.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
        let distribution = entry["distribution"] as? String,
        distribution == "discrete" || distribution == "uniformDensityFraction"
      else { return nil }
      let commodity = (entry["commodityIndex"] as? Int).flatMap(CommodityIdentity.init(rawValue:))
      guard (field == .cargo) == (commodity != nil) else { return nil }
      let nativeUnit = entry["nativeUnit"] as? String
      if let commodity, nativeUnit != commodity.unit { return nil }
      let allocationValues: [[String: Any]]
      if field == .cargo {
        guard entry["sharedMixtureGroup"] as? String == "cargo",
          let constituents = entry["unitConstituents"] as? [[String: Any]],
          constituents.count == 2 else { return nil }
        allocationValues = constituents
      } else {
        var value = rawMass
        value["dimensionsMetres"] = dimensions
        value["shape"] = "effectiveUniformBoxMassModel"
        allocationValues = [value]
      }
      let allocations = allocationValues.compactMap(Self.allocation)
      guard allocations.count == allocationValues.count,
        let aggregate = CurrentNewtKitMass.combined(allocations.map(\.mass)),
        CurrentNewtKitMass.close(aggregate, mass, massTolerance: 1e-8,
          centreTolerance: 1e-9, inertiaTolerance: 1e-6)
      else { return nil }
      rules.append(.init(field: field, commodity: commodity, unit: mass,
        centres: positions.map { .init($0[0], $0[1], $0[2]) },
        distributed: distribution == "uniformDensityFraction", nativeUnit: nativeUnit,
        alwaysPresent: field == .ecm, allocations: allocations))
    }
    let keys = rules.map { $0.field.rawValue + ":" + String($0.commodity?.rawValue ?? -1) }
    let fixed = fixedValues.compactMap(CurrentNewtKitGeometry.mass)
    let fixedAllocations = fixedValues.compactMap(Self.allocation)
    guard Set(keys).count == keys.count, fixed.count == fixedValues.count,
      fixedAllocations.count == fixedValues.count,
      maximumCargo.isFinite, maximumCargo > 0, maximumFuel.isFinite, maximumFuel >= 0,
      maximumMissiles >= 0 else { return nil }
    return .init(catalogueShipID: catalogue, r3SHA256: r3, rules: rules, fixed: fixed, fixedAllocations: fixedAllocations,
      maximumCargoMassKilograms: maximumCargo, maximumFuelTenthsLY: maximumFuel,
      maximumMissiles: maximumMissiles)
  }

  func matches(_ load: CurrentNewtKitLoad, selectedPerson: EMPCrewIdentity) -> Bool {
    load.people.count == 1 && load.people.first?.identity == selectedPerson
      && matchesInventory(load)
  }

  /// Empty parent rosters are valid after a genuine person handoff; this does
  /// not qualify an issue or select a person for release.
  func matchesInventory(_ load: CurrentNewtKitLoad) -> Bool {
    guard load.structurallyValid, load.catalogueShipID == catalogueShipID,
      load.r3SHA256 == r3SHA256, load.hasFuelScoops == false,
      let current = OriginalFleetR3Data.contract(for: catalogueShipID),
      current.sourceSHA256 == r3SHA256, let performance = current.performance,
      let expected = NPCResources.stock(performance), let fuel = load.resources.fuel,
      fuel >= 0, fuel <= (expected.fuelCapacity ?? -1),
      Double(fuel) + load.resources.scoopRemainder <= maximumFuelTenthsLY,
      load.resources.scoopRemainder >= 0 && load.resources.scoopRemainder < 1,
      load.missiles <= min(performance.missiles, maximumMissiles),
      load.resources.profile == expected.profile,
      load.resources.heatCapacity == expected.heatCapacity,
      load.resources.heatCooling == expected.heatCooling,
      load.resources.energyCapacity == expected.energyCapacity,
      load.resources.energyRecharge == expected.energyRecharge,
      load.resources.frontCapacity == expected.frontCapacity,
      load.resources.rearCapacity == expected.rearCapacity,
      load.resources.shieldRecharge == expected.shieldRecharge,
      load.resources.fuelCapacity == expected.fuelCapacity
    else { return false }
    var tonnes = 0
    var cargoMass = 0.0
    for amount in load.cargo {
      guard amount.valid, amount.tonnes <= performance.cargo - tonnes else { return false }
      tonnes += amount.tonnes
      guard let model = rule(.cargo, commodity: amount.commodity) else { return false }
      cargoMass += model.unit.massKilograms * Double(amount.quantity)
      guard cargoMass.isFinite, cargoMass <= maximumCargoMassKilograms else { return false }
    }
    if fuel > 0 && rule(.fuel) == nil { return false }
    if load.missiles > 0 && rule(.missiles) == nil { return false }
    if load.ecmEnabled && rule(.ecm) == nil { return false }
    return masses(load) != nil
  }

  func masses(_ load: CurrentNewtKitLoad) -> [CurrentNewtKitReceipt.MassProperties]? {
    allocations(load)?.map(\.mass)
  }

  /// Merge actual cargo fractions into their two shared beds. This preserves
  /// the declared gap and never overlays one solid box per commodity.
  func allocations(_ load: CurrentNewtKitLoad) -> [Allocation]? {
    var result = fixedAllocations
    var cargo: [String: Allocation] = [:]
    for rule in rules {
      let count: Double
      switch rule.field {
      case .cargo: count = Double(load.cargo.first(where: { $0.commodity == rule.commodity })?.quantity ?? 0)
      case .fuel:
        guard let fuel = load.resources.fuel else { return nil }
        count = Double(fuel) + load.resources.scoopRemainder
      case .missiles: count = Double(load.missiles)
      case .ecm: count = rule.alwaysPresent || load.ecmEnabled ? 1 : 0
      }
      guard count.isFinite, count >= 0 else { return nil }
      if count == 0 { continue }
      if rule.distributed {
        guard rule.centres.count == 1 else { return nil }
        for allocation in rule.allocations {
          let scaled = scaled(allocation.mass, by: count, offset: rule.centres[0])
          if rule.field == .cargo {
            if let existing = cargo[allocation.id] {
              guard let combined = CurrentNewtKitMass.combined([existing.mass, scaled]) else { return nil }
              cargo[allocation.id] = .init(id: allocation.id, mass: combined, mesh: allocation.mesh)
            } else {
              cargo[allocation.id] = .init(id: allocation.id, mass: scaled, mesh: allocation.mesh)
            }
          } else {
            result.append(.init(id: allocation.id, mass: scaled, mesh: allocation.mesh, offset: rule.centres[0]))
          }
        }
      } else {
        guard count.rounded() == count, count <= Double(rule.centres.count),
          rule.allocations.count == 1, let allocation = rule.allocations.first else { return nil }
        for (index, centre) in rule.centres.prefix(Int(count)).enumerated() {
          result.append(.init(id: allocation.id + "-" + String(index),
            mass: CurrentNewtKitMass.translated(allocation.mass, by: centre), mesh: allocation.mesh, offset: centre))
        }
      }
    }
    result += cargo.keys.sorted().compactMap { cargo[$0] }
    return result.allSatisfy { CurrentNewtKitMass.componentIsValid($0.mass) } ? result : nil
  }

  private func scaled(_ mass: CurrentNewtKitReceipt.MassProperties, by factor: Double,
    offset: Vector3) -> CurrentNewtKitReceipt.MassProperties
  {
    .init(massKilograms: mass.massKilograms * factor,
      centreOfMassMetres: mass.centreOfMassMetres + offset,
      inertiaKgM2: mass.inertiaKgM2.map { $0 * factor })
  }

  private static func allocation(_ value: [String: Any]) -> Allocation? {
    var geometry = value
    if value["cavityDimensionsMetres"] != nil { geometry["shape"] = "hollowStorageAssembly" }
    guard let id = value["id"] as? String, let mass = CurrentNewtKitGeometry.mass(part: value),
      let mesh = CurrentNewtKitGeometry.mesh(part: geometry) else { return nil }
    return .init(id: id, mass: mass, mesh: mesh)
  }

  private func rule(_ field: Field, commodity: CommodityIdentity? = nil) -> Rule? {
    rules.first { $0.field == field && $0.commodity == commodity }
  }
}
