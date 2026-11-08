import Foundation

/// Read the delivered current fit only when its identity, mechanics and empty-fit counts agree.
/// This projects capacities; it installs no device, cabin, crew or purchase entitlement.
enum OriginalFleetR3Fitting {
  static func matchesCurrentMechanics(_ ship: CatalogueShip) -> Bool {
    guard let current = OriginalFleetR3Data.contract(for: ship.id),
      let performance = current.performance
    else { return false }
    return ship.name == current.name && ship.catalogue.family == current.family
      && ship.game == performance
  }

  static func contract(for ship: CatalogueShip) -> OriginalFleetR3Contract? {
    guard let current = OriginalFleetR3Data.contract(for: ship.id),
      current.objectKind == .ship, ship.catalogue.objectKind == .ship,
      ship.catalogue.origin == current.origin.catalogueOrigin,
      current.name == ship.name, current.family == ship.catalogue.family,
      current.performance == ship.game, let crew = current.accommodation,
      let fitting = current.fitting, !fitting.roleKitIncluded, crew.initialPurchasedCabins == 0,
      let nativeUnits = nativeEquipmentUnits(for: ship, contract: current)
    else { return nil }
    let profiles = ship.profiles.filter { $0.group == "project-refit-v1" }
    guard profiles.count == 1, let profile = profiles.first else { return nil }
    func matches(_ key: String, _ count: Int) -> Bool {
      let fields = profile.fields.filter { $0.key == key }
      return fields.count == 1 && fields[0].number == Double(count)
    }
    guard matches("required_crew_including_commander", crew.operatingCrew),
      matches("reserved_crew_accommodation", crew.intrinsicCrewPlaces),
      matches("equipment_capacity_units", nativeUnits),
      matches("initial_charter_passenger_berths", 0)
    else { return nil }
    return current
  }

  /// Keep the three existing explicit native capacity adapters separate from worksheet totals.
  /// Intrinsic foundation items retain their actual zero cost; no four equipment nodes are issued.
  static func nativeEquipmentUnits(
    for ship: CatalogueShip, contract: OriginalFleetR3Contract
  ) -> Int? {
    guard contract.id == ship.id, let fitting = contract.fitting else { return nil }
    let planning: Int
    let usable: Int
    switch ship.id {
    case "SH013":
      planning = 34
      usable = 30
    case "SH014":
      planning = 38
      usable = 34
    case "SH026":
      planning = 18
      usable = 14
    default: return fitting.equipmentUnits
    }
    let declarations = ship.profiles.filter { $0.group == "project-refit-v1" }.flatMap(\.fields)
      .filter { $0.key == "fleet_r3_planning_budget_including_structural_reservation" }
    guard fitting.equipmentUnits == planning, declarations.count == 1,
      declarations[0].number == Double(planning)
    else { return nil }
    return usable
  }

  static func validateUtilities(
    _ inventory: OwnedEquipmentInventory, ship: CatalogueShip, allowsXYZzyMaximumOutfit: Bool = false
  ) throws {
    guard let source = contract(for: ship), let fitting = source.fitting else {
      guard OriginalFleetR3Data.contract(for: ship.id) == nil else {
        throw CommanderEquipmentError.invalidRuntimeStatistics
      }
      return
    }
    let mounted = inventory.items.filter { item in
      guard let location = item.location, location.hullInstanceID == inventory.activeHull else {
        return false
      }
      switch location.slot {
      case .utility, .fuelStorage: return true
      default: return false
      }
    }
    let ordinaryMountCount = mounted.filter {
      !allowsXYZzyMaximumOutfit || $0.provenance != .xyzzy
    }.count
    guard ordinaryMountCount <= fitting.utilityMounts else {
      throw CommanderEquipmentError.invalidRuntimeStatistics
    }
    // Native defensive device compatibility stays with its existing module graph.
    // R3 declares work/scoop capabilities separately; actual installed slots consume mounts.
    for item in mounted {
      guard let slot = item.location?.slot else { continue }
      switch slot {
      case .fuelStorage:
        guard fitting.compatibleUtilities.contains("auxiliaryFuelTank")
          || (allowsXYZzyMaximumOutfit && item.provenance == .xyzzy)
        else {
          throw CommanderEquipmentError.invalidRuntimeStatistics
        }
      case .utility(.salvageCutter):
        guard fitting.compatibleUtilities.contains("salvageCutter") else {
          throw CommanderEquipmentError.invalidRuntimeStatistics
        }
      case .utility(.miningLaser):
        guard fitting.compatibleUtilities.contains("miningLaser") else {
          throw CommanderEquipmentError.invalidRuntimeStatistics
        }
      case .utility(.fuelScoops):
        guard fitting.compatibleUtilities.contains("cargoScoop") else {
          throw CommanderEquipmentError.invalidRuntimeStatistics
        }
      default: break
      }
    }
  }
}
