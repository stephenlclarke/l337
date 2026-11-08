import Foundation

extension CurrentNewtKitSource {
  struct FixedPart: Sendable {
    let id: String
    let mass: Mass
    let collisionMesh: Mesh?
    let displayMesh: Mesh?
  }

  struct PersonSlot: Sendable {
    let ordinal: Int
    let componentID: String
    let profile: CurrentNewtKitIssue.PersonProfile
    let massInCarrier: Mass
  }

  struct DriveContactPair: Sendable {
    let driverID: String
    let shoeID: String
  }

  struct CarrierCellService: Sendable {
    let componentIDs: [String]
    let electricalJoules: Double
    let startupElectricalJoules: Double
    let continuousWatts: Double
    let oxygenKilograms: Double
    let sorbentCapacityKilogramsCO2: Double
    let oxygenKgPerSecond: Double
    let carbonDioxideKgPerSecond: Double
    let pressurePascals: Double
    let temperatureKelvin: Double
    let transferSealClosed: Bool
  }

  /// Closed set of current authenticated assets. This reads physical data and
  /// grants no selector, stock, actor, ordinal or admission rights to a caller.
  static var resourceFileNames: Set<String> {
    [CurrentNewtKitPhysicalSource.resourceFileName, CurrentBisonWideShoePhysicalSource.resourceFileName,
      CurrentBisonWideShoePhysicalSource.commissioningFileName]
  }

  static func source(for issue: CurrentNewtKitIssue) -> Self? {
    switch (issue.configuration, issue.sourceSHA256, issue.birthLoad.catalogueShipID) {
    case (CurrentNewtKitPhysicalSource.configurationID, CurrentNewtKitPhysicalSource.sourceSHA256, "SH029"):
      return current
    case (CurrentBisonWideShoePhysicalSource.configurationID, CurrentBisonWideShoePhysicalSource.sourceSHA256, "SH005"):
      return bison
    default: return nil
    }
  }

  static func birthSource(for request: SpawnRequest, context: EncounterContext) -> Self? {
    let candidate: Self?
    switch (request.currentNewtKitConfiguration, request.catalogueShipID) {
    case (CurrentNewtKitPhysicalSource.configurationID, "SH029"): candidate = current
    case (CurrentBisonWideShoePhysicalSource.configurationID, "SH005"): candidate = bison
    default: candidate = nil
    }
    guard let candidate, candidate.permitsBirth(request, context: context) else { return nil }
    return candidate
  }
}

extension CurrentNewtKitSource {
  func initialCarrierCells(at time: Double) -> [CurrentNewtKitIssue.CarrierCell]? {
    guard let service = carrierCellService else { return nil }
    return service.componentIDs.map { component in
      .init(componentID: component, commissionedAt: time,
        electricalJoules: service.electricalJoules - service.startupElectricalJoules,
        oxygenKilograms: service.oxygenKilograms,
        sorbentCapacityKilogramsCO2: service.sorbentCapacityKilogramsCO2,
        pressurePascals: service.pressurePascals, temperatureKelvin: service.temperatureKelvin,
        transferSealClosed: service.transferSealClosed)
    }
  }

  func matchesCarrierCells(_ issue: CurrentNewtKitIssue) -> Bool {
    guard let service = carrierCellService else { return issue.carrierCells == nil }
    guard service.transferSealClosed, service.pressurePascals > 0, service.temperatureKelvin > 0,
      let cells = issue.carrierCells, cells == initialCarrierCells(at: issue.issuedAt)
    else { return false }
    return cells.count == originalNativeCrew && Set(cells.map(\.componentID)).count == cells.count
  }
}

extension CurrentNewtKitSource {
  func currentParentPeople(_ load: CurrentNewtKitLoad) -> [PersonSlot]? {
    guard loadModel?.matchesInventory(load) == true else { return nil }
    return personSlots.filter { slot in
      slot.ordinal != selectedPersonOrdinal && load.people.contains {
        $0.identity.ordinal == slot.ordinal && $0.profile == slot.profile
      }
    }
  }
}

extension CurrentNewtKitSource {
  /// Only the exact configured selected person is removed. Shared display
  /// geometry is independently authenticated; each configuration proves its own
  /// remaining component IDs and full physical tensor.
  func emptyCellParts() -> ([ReleasedPart], Mass)? {
    guard releasedParts.filter({ $0.id == selectedPersonComponentID }).count == 1,
      releasedParts.filter({ $0.id == dryPodComponentID }).count == 1,
      let display = CurrentNewtEmptyCellDisplaySource.emptyDisplayMesh else { return nil }
    let parts = releasedParts.compactMap { part -> ReleasedPart? in
      if part.id == selectedPersonComponentID { return nil }
      return .init(id: part.id, mass: part.mass, collisionMesh: part.collisionMesh,
        displayMesh: part.id == dryPodComponentID ? display : part.displayMesh)
    }
    guard parts.count == 5, let mass = CurrentNewtKitMass.combined(parts.map(\.mass)) else { return nil }
    switch configuration {
    case CurrentNewtEmptyCellPhysicalSource.configurationID:
      guard sourceSHA256 == CurrentNewtEmptyCellPhysicalSource.configuredSourceSHA256,
        selectedPersonOrdinal == CurrentNewtEmptyCellPhysicalSource.removedOriginalPersonOrdinal,
        parts.map(\.id) == CurrentNewtEmptyCellPhysicalSource.retainedComponentIDs,
        parts.map({ $0.mass.massKilograms }) == CurrentNewtEmptyCellPhysicalSource.retainedComponentMassKilograms,
        CurrentNewtEmptyCellPhysicalSource.cellWithoutSelectedPerson.matches(
          massKilograms: mass.massKilograms, centreMetres: mass.centreOfMassMetres,
          inertiaAboutCentreOfMassKgM2: mass.inertiaKgM2) else { return nil }
    case CurrentBisonWideShoePhysicalSource.configurationID:
      guard sourceSHA256 == CurrentBisonWideShoePhysicalSource.sourceSHA256,
        selectedPersonOrdinal == CurrentBisonWideShoePhysicalSource.selectedPersonOrdinal,
        CurrentBisonWideShoePhysicalSource.emptyConfiguredPod.matches(
          massKilograms: mass.massKilograms, centreMetres: mass.centreOfMassMetres,
          inertiaKgM2: mass.inertiaKgM2) else { return nil }
    default: return nil
    }
    return (parts, mass)
  }
}

extension CurrentNewtKitSource {
  var driveRolesAreCoherent: Bool {
    let moving = Set(retainedParts.filter { $0.lowered != $0.extended }.map(\.id))
    if let bisonCommissioning {
      guard bisonCommissioning.matchesParts(retained: retainedParts, released: releasedParts),
        driveContactPairs.map(\.driverID) == bisonCommissioning.driveContactPairs.map(\.capComponentID),
        driveContactPairs.map(\.shoeID) == bisonCommissioning.driveContactPairs.map(\.shoeComponentID)
      else { return false }
    }
    return moving == movingDriveComponentIDs && !moving.isEmpty
      && driveFollowerComponentIDs.isSubset(of: moving) && driveContactPairs.count == 2
      && Set(driveContactPairs.map(\.driverID)).count == driveContactPairs.count
      && Set(driveContactPairs.map(\.shoeID)).count == driveContactPairs.count
      && driveContactPairs.allSatisfy { pair in
        moving.contains(pair.driverID) && !driveFollowerComponentIDs.contains(pair.driverID)
          && releasedParts.contains { $0.id == pair.shoeID && $0.collisionMesh != nil }
      }
  }
}

extension CurrentNewtKitSource {
  /// Separate material constraints, not additional actuator-force interfaces.
  /// Native owners must join all four actual pairs in their one unilateral solve.
  var passiveDriveMaterialContactPairs: [CurrentBisonWideShoeCommissioning.PassivePair] {
    bisonCommissioning?.passiveDriveMaterialContactPairs ?? []
  }
}
